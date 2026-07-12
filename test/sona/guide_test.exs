defmodule Sona.GuideTest do
  use Sona.DataCase, async: false

  alias Sona.Accounts.{Company, User}
  alias Sona.Guide
  alias Sona.Guide.GuideConversation
  alias Sona.Guide.GuideMessage
  alias Sona.Repo

  setup do
    company = Repo.insert!(%Company{name: "Test Hotel", invite_token: "test123"})
    user = Repo.insert!(%User{company_id: company.id, username: "alice", display_name: "Alice"})
    %{company: company, user: user}
  end

  describe "ensure_conversation/1" do
    test "creates a conversation for a user", %{user: user} do
      conversation = Guide.ensure_conversation(user)
      assert conversation.user_id == user.id
      assert conversation.company_id == user.company_id
      assert Repo.get(GuideConversation, conversation.id)
    end

    test "is idempotent", %{user: user} do
      c1 = Guide.ensure_conversation(user)
      c2 = Guide.ensure_conversation(user)
      assert c1.id == c2.id
    end

    test "handles concurrent creation by rescuing unique constraint", %{user: user} do
      # Insert directly to simulate a concurrent insert
      existing =
        %GuideConversation{company_id: user.company_id, user_id: user.id}
        |> GuideConversation.changeset(%{})
        |> Repo.insert!()

      # ensure_conversation should rescue the constraint and re-fetch
      conversation = Guide.ensure_conversation(user)
      assert conversation.id == existing.id

      assert Repo.aggregate(GuideConversation, :count) == 1
    end
  end

  describe "list_messages/1" do
    test "returns empty list for a user with no messages", %{user: user} do
      assert Guide.list_messages(user) == []
    end

    test "returns messages when called with %GuideConversation{}", %{user: user} do
      conversation = Guide.ensure_conversation(user)
      insert_guide_message(conversation, :user, "Hello")
      insert_guide_message(conversation, :assistant, "Hi")

      messages = Guide.list_messages(conversation)
      assert length(messages) == 2

      bodies = MapSet.new(messages, & &1.body)
      assert "Hello" in bodies
      assert "Hi" in bodies
    end

    test "returns messages when called with %User{}", %{user: user} do
      conversation = Guide.ensure_conversation(user)
      insert_guide_message(conversation, :user, "First")
      insert_guide_message(conversation, :assistant, "Second")

      messages = Guide.list_messages(user)
      assert length(messages) == 2

      bodies = MapSet.new(messages, & &1.body)
      assert "First" in bodies
      assert "Second" in bodies
    end

    test "limits to 50 messages", %{user: user} do
      conversation = Guide.ensure_conversation(user)

      for i <- 1..60 do
        insert_guide_message(conversation, :user, "Message #{i}")
      end

      messages = Guide.list_messages(user)
      assert length(messages) == 50
    end
  end

  describe "latest_guide_summary/1" do
    test "returns map with nil teaser for a user with no messages", %{user: user} do
      summary = Guide.latest_guide_summary(user)
      assert summary.teaser == nil
      assert %NaiveDateTime{} = summary.inserted_at
    end

    test "returns the latest message body and timestamp", %{user: user} do
      conversation = Guide.ensure_conversation(user)
      insert_guide_message(conversation, :assistant, "Welcome to the guide!")

      summary = Guide.latest_guide_summary(user)
      assert summary.teaser == "Welcome to the guide!"
      assert %NaiveDateTime{} = summary.inserted_at
    end

    test "auto-ensures the conversation", %{user: user} do
      assert Repo.aggregate(GuideConversation, :count) == 0

      _summary = Guide.latest_guide_summary(user)

      assert Repo.aggregate(GuideConversation, :count) == 1
    end
  end

  describe "send_user_message/2" do
    test "inserts user and assistant messages and broadcasts both", %{user: user} do
      Guide.subscribe_guide(user)

      assert {:ok, assistant_msg} = Guide.send_user_message(user, "Hello guide")
      assert assistant_msg.role == :assistant
      assert assistant_msg.body == "This is a stub reply from the AI Guide."

      # Verify persisted messages
      conversation = Guide.ensure_conversation(user)
      messages = Guide.list_messages(conversation)
      assert length(messages) == 2

      # Check by role (order not guaranteed with same-second timestamps)
      user_msg = Enum.find(messages, &(&1.role == :user))
      reply_msg = Enum.find(messages, &(&1.role == :assistant))
      assert user_msg.body == "Hello guide"
      assert reply_msg.role == :assistant

      # Verify broadcasts
      assert_received {:new_guide_message, %GuideMessage{role: :user}}
      assert_received {:new_guide_message, %GuideMessage{role: :assistant}}
    end

    test "builds history including seeded proactive messages", %{user: user} do
      # Seed a proactive message first
      Guide.seed_proactive_message(user, "Welcome! I'm your AI guide")

      Guide.subscribe_guide(user)

      assert {:ok, _assistant_msg} = Guide.send_user_message(user, "Hello")

      # All 3 messages persisted: proactive + user + assistant
      conversation = Guide.ensure_conversation(user)
      messages = Guide.list_messages(conversation)
      assert length(messages) == 3

      # Verify all three roles are present (order not guaranteed with same timestamp)
      roles = MapSet.new(messages, & &1.role)
      assert :user in roles
      assert :assistant in roles

      # Verify the proactive message body is present
      bodies = MapSet.new(messages, & &1.body)
      assert "Welcome! I'm your AI guide" in bodies
      assert "Hello" in bodies
    end

    test "returns error when LLM stub returns error, keeping the user message", %{user: user} do
      Application.put_env(:sona, :guide_llm_stub_should_error, true)

      try do
        assert {:error, :stub_forced_error} = Guide.send_user_message(user, "Hello")
      after
        Application.delete_env(:sona, :guide_llm_stub_should_error)
      end

      # User message should still be persisted
      conversation = Guide.ensure_conversation(user)
      messages = Guide.list_messages(conversation)
      assert length(messages) == 1
      assert hd(messages).role == :user
      assert hd(messages).body == "Hello"
    end
  end

  describe "seed_proactive_message/2" do
    test "inserts an assistant message with no LLM call", %{user: user} do
      msg = Guide.seed_proactive_message(user, "Welcome to the AI Guide!")

      assert msg.role == :assistant
      assert msg.body == "Welcome to the AI Guide!"
      assert msg.__meta__.state == :loaded

      # Verify it's persisted
      conversation = Guide.ensure_conversation(user)
      messages = Guide.list_messages(conversation)
      assert length(messages) == 1
      assert hd(messages).id == msg.id
    end

    test "can insert multiple proactive messages", %{user: user} do
      msg1 = Guide.seed_proactive_message(user, "First message")
      msg2 = Guide.seed_proactive_message(user, "Second message")

      assert msg1.id != msg2.id

      conversation = Guide.ensure_conversation(user)
      messages = Guide.list_messages(conversation)
      assert length(messages) == 2
    end

    test "re-fetches the conversation internally", %{user: user} do
      _conversation = Guide.ensure_conversation(user)

      # The function should work with just %User{} and body
      msg = Guide.seed_proactive_message(user, "Proactive!")
      assert msg.role == :assistant
    end
  end

  describe "subscribe_guide/1" do
    test "subscribes to the user's guide PubSub topic", %{user: user} do
      Guide.subscribe_guide(user)

      Phoenix.PubSub.broadcast(Sona.PubSub, "guide:user:#{user.id}", :test_event)
      assert_received :test_event
    end
  end

  describe "company scoping" do
    test "users from different companies get separate conversations", %{} do
      company_a = Repo.insert!(%Company{name: "Acme", invite_token: "a1"})
      company_b = Repo.insert!(%Company{name: "Beta", invite_token: "b1"})

      user_a =
        Repo.insert!(%User{
          company_id: company_a.id,
          username: "alice_a",
          display_name: "Alice A"
        })

      user_b =
        Repo.insert!(%User{company_id: company_b.id, username: "bob_b", display_name: "Bob B"})

      # User A creates a conversation and sends a message
      conv_a = Guide.ensure_conversation(user_a)
      assert conv_a.company_id == company_a.id
      Guide.send_user_message(user_a, "Hello from Acme")

      # User B has their own empty conversation
      conv_b = Guide.ensure_conversation(user_b)
      assert conv_b.company_id == company_b.id
      assert conv_b.id != conv_a.id
      assert Guide.list_messages(user_b) == []
    end
  end

  describe "Sona.Guide does not call Sona.Chats" do
    test "module code does not alias, import, or call Sona.Chats" do
      source = File.read!("lib/sona/guide.ex")
      # Strip doc strings to avoid matching prose references
      stripped = String.replace(source, ~r/""".*?"""/s, "")
      refute stripped =~ "Sona.Chats"
      refute stripped =~ "Sona.Chat."
    end
  end

  defp insert_guide_message(conversation, role, body) do
    %GuideMessage{conversation_id: conversation.id}
    |> GuideMessage.changeset(%{body: body})
    |> Ecto.Changeset.put_change(:role, role)
    |> Repo.insert!()
  end
end
