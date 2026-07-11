defmodule SonaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SonaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope (user + company)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header
      id="app-header"
      class="sticky top-0 z-40 flex items-center justify-between border-b border-base-300 bg-base-100 px-4 py-2 sm:px-6"
    >
      <div class="flex items-center gap-2 min-w-0">
        <.link
          navigate={~p"/"}
          id="sona-wordmark"
          class="text-lg font-semibold tracking-tight shrink-0"
        >
          Sona.
        </.link>
      </div>

      <div :if={@current_scope} class="flex items-center gap-2 sm:gap-3 text-sm min-w-0">
        <span id="user-company-label" class="truncate text-base-content/70">
          {@current_scope.user.username} @ {@current_scope.company.name}
        </span>
        <form action={~p"/session"} method="post" id="sign-out-form" class="shrink-0">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="_csrf_token" value={get_csrf_token()} />
          <button
            type="submit"
            id="sign-out-button"
            class="text-sm text-base-content/60 hover:text-base-content underline-offset-2 hover:underline"
          >
            Sign out
          </button>
        </form>
      </div>
    </header>

    <main class="mx-auto w-full max-w-2xl px-4 py-3 sm:px-6 sm:py-4">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
