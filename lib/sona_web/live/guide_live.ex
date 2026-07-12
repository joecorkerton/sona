defmodule SonaWeb.GuideLive do
  @moduledoc """
  Placeholder for the AI Shift Guide conversation LiveView.

  The real implementation (chat-style streams + composer + PubSub + LLM
  reply loop) lands in issue 019 (`plans/ai-shift-guide.md`). This stub
  exists only so that the `live "/guide", GuideLive` route added by
  issue 020 compiles cleanly — the `<.link navigate={~p"/guide"}>`
  reference on `/chats` requires a route to exist at compile time.

  Until 019 lands, opening `/guide` renders a minimal placeholder. The
  conversation is still auto-ensured by `Sona.Guide.ensure_conversation/1`
  (called by `latest_guide_summary/1` on the inbox side) so there is no
  data inconsistency to worry about.
  """

  use SonaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Sona Guide")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-4">
        <h1 class="text-2xl font-bold text-base-content sm:text-3xl">Sona Guide</h1>
        <p class="text-sm text-base-content/60">
          Your AI shift guide is coming soon. Check back later.
        </p>
      </div>
    </Layouts.app>
    """
  end
end
