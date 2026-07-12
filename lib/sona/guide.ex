defmodule Sona.Guide do
  @moduledoc """
  Context for guide conversations and messages.

  Owns the public API for the AI Shift Guide feature: creating conversations,
  listing messages, sending messages (which triggers the LLM loop), and
  subscribing to real-time updates.

  Company scoping: every lookup filters by `user.company_id` to ensure users
  can only access their own company's guide data.

  `Sona.Guide` depends only on `Sona.Accounts` (`%User{}` / `%Company{}`) and
  `Sona.Repo`. It does **not** call `Sona.Chats` and vice versa.
  """

  import Ecto.Query

  alias Sona.Accounts.User
  alias Sona.Guide.GuideConversation
  alias Sona.Guide.GuideMessage
  alias Sona.Guide.LLM
  alias Sona.Guide.Prompt
  alias Sona.Guide.ShiftData
  alias Sona.Repo

  @doc """
  Returns the user's guide conversation, creating one if it doesn't exist.

  Idempotent: concurrent calls for the same user will produce a single row
  (rescues the `user_id` unique constraint and re-fetches).

  ## Examples

      iex> conversation = Sona.Guide.ensure_conversation(user)
      iex> conversation.user_id == user.id
      true
      iex> conversation.company_id == user.company_id
      true
  """
  @spec ensure_conversation(User.t()) :: GuideConversation.t()
  def ensure_conversation(%User{} = user) do
    case Repo.get_by(GuideConversation, user_id: user.id) do
      nil -> create_conversation(user)
      conversation -> conversation
    end
  end

  @doc """
  Lists the last 50 guide messages for a conversation, oldest→newest.

  Accepts either a `%User{}` (auto-ensures the conversation) or a
  `%GuideConversation{}`. Messages are not preloaded (no user association on
  guide messages).

  **Company scoping**: when called with `%User{}`, the conversation is
  resolved via the company-scoped `ensure_conversation/1`. When called with
  `%GuideConversation{}`, the function trusts the caller — in practice the
  conversation was obtained through `ensure_conversation/1` (which enforces
  company scoping). This two-argument form is provided for convenience when
  the caller already holds the conversation struct.

  ## Examples

      iex> Sona.Guide.list_messages(user)
      [%GuideMessage{...}, ...]

      iex> Sona.Guide.list_messages(conversation)
      [%GuideMessage{...}, ...]
  """
  @spec list_messages(User.t() | GuideConversation.t()) :: [GuideMessage.t()]
  def list_messages(%User{} = user) do
    conversation = ensure_conversation(user)
    query_messages(conversation)
  end

  def list_messages(%GuideConversation{} = conversation) do
    query_messages(conversation)
  end

  @doc """
  Returns a summary map for the latest guide message, auto-ensuring the
  conversation first.

  Always returns `%{teaser: String.t() | nil, inserted_at: NaiveDateTime.t()}` —
  never the atom `nil`. The `teaser` is `nil` only when the conversation
  has no messages yet (fresh, unseeded user).

  Note: timestamps on `GuideConversation` use Ecto's default `:naive_datetime`,
  so `inserted_at` is `%NaiveDateTime{}`, not `%DateTime{}`.
  """
  @spec latest_guide_summary(User.t()) :: %{
          teaser: String.t() | nil,
          inserted_at: NaiveDateTime.t()
        }
  def latest_guide_summary(%User{} = user) do
    conversation = ensure_conversation(user)

    case Repo.one(
           from m in GuideMessage,
             where: m.conversation_id == ^conversation.id,
             order_by: [desc: m.inserted_at, desc: m.id],
             limit: 1,
             select: {m.body, m.inserted_at}
         ) do
      {body, inserted_at} -> %{teaser: body, inserted_at: inserted_at}
      nil -> %{teaser: nil, inserted_at: conversation.inserted_at}
    end
  end

  @doc """
  Sends a user message in the guide conversation and returns the AI's
  assistant reply.

  Flow:
  1. Insert `:user` message
  2. Broadcast `{:new_guide_message, msg}` on `"guide:user:<user.id>"`
  3. Build system prompt via `Sona.Guide.Prompt.build/2` with `Sona.Guide.ShiftData.for/1`
  4. Build history — all prior `guide_messages` oldest→newest mapped to `%{role, content}`
     (includes any seeded proactive `:assistant` message)
  5. Call `Sona.Guide.LLM.reply/3` with system prompt, history, and user text
  6. Insert `:assistant` message
  7. Broadcast `{:new_guide_message, assistant_msg}`

  On LLM error, the user message is kept (not rolled back) so the user can
  see what they sent even if the AI failed to respond, and `{:error,
  reason}` is returned.
  """
  @spec send_user_message(User.t(), String.t()) :: {:ok, GuideMessage.t()} | {:error, term()}
  def send_user_message(%User{} = user, text) when is_binary(text) do
    user = Repo.preload(user, :company)
    conversation = ensure_conversation(user)

    # Insert and broadcast user message
    user_msg = insert_message(conversation, :user, text)
    broadcast(user.id, {:new_guide_message, user_msg})

    # Build system prompt
    shift_data = ShiftData.for(user)
    system_prompt = Prompt.build(user, shift_data)

    # Build history — all prior messages including any seeded proactive one
    history =
      Repo.all(
        from m in GuideMessage,
          where: m.conversation_id == ^conversation.id,
          order_by: [asc: m.inserted_at, asc: m.id],
          select: %{role: m.role, content: m.body}
      )

    # Call LLM
    case LLM.reply(system_prompt, history, text) do
      {:ok, reply_text} ->
        assistant_msg = insert_message(conversation, :assistant, reply_text)
        broadcast(user.id, {:new_guide_message, assistant_msg})
        {:ok, assistant_msg}

      {:error, reason} ->
        # User message is kept — the user can see what they sent even if
        # the AI failed to respond. See issue 018 Notes for rationale.
        {:error, reason}
    end
  end

  @doc """
  Inserts a hardcoded proactive `:assistant` message with **no** LLM call or
  prompt building. Used by seeds to insert the welcome message.

  Re-fetches the conversation internally — callers pass only `%User{}` and body.
  """
  @spec seed_proactive_message(User.t(), String.t()) :: GuideMessage.t()
  def seed_proactive_message(%User{} = user, body) when is_binary(body) do
    conversation = ensure_conversation(user)
    insert_message(conversation, :assistant, body)
  end

  @doc """
  Subscribes the calling process to PubSub updates for the user's guide.

  Topic format: `"guide:user:<user.id>"`. Both user and assistant messages
  are broadcast as `{:new_guide_message, msg}`.
  """
  @spec subscribe_guide(User.t()) :: :ok | {:error, term()}
  def subscribe_guide(%User{} = user) do
    Phoenix.PubSub.subscribe(Sona.PubSub, topic(user.id))
  end

  # --- private helpers ---

  defp create_conversation(user) do
    %GuideConversation{company_id: user.company_id, user_id: user.id}
    |> GuideConversation.changeset(%{})
    |> Repo.insert()
    |> case do
      {:ok, conversation} ->
        conversation

      {:error, changeset} ->
        if unique_user_id_violation?(changeset) do
          # Rescue unique constraint on user_id (concurrent creation)
          Repo.get_by!(GuideConversation, user_id: user.id)
        else
          raise Ecto.InvalidChangesetError, changeset: changeset
        end
    end
  end

  defp unique_user_id_violation?(changeset) do
    Enum.any?(changeset.errors, fn {field, {_msg, opts}} ->
      field == :user_id and opts[:constraint] == :unique and
        to_string(opts[:constraint_name]) == "guide_conversations_user_id_index"
    end)
  end

  defp query_messages(conversation) do
    Repo.all(
      from m in GuideMessage,
        where: m.conversation_id == ^conversation.id,
        order_by: [asc: m.inserted_at, asc: m.id],
        limit: 50
    )
  end

  defp insert_message(conversation, role, body) do
    %GuideMessage{conversation_id: conversation.id}
    |> GuideMessage.changeset(%{body: body})
    |> Ecto.Changeset.put_change(:role, role)
    |> Repo.insert!()
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(Sona.PubSub, topic(user_id), message)
  end

  defp topic(user_id), do: "guide:user:#{user_id}"
end
