defmodule SonaWeb.JoinLive do
  use SonaWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    token = params["token"]
    company = Sona.Accounts.get_company_by_invite_token(token)

    socket =
      if company do
        form = to_form(%{"username" => ""})

        socket
        |> assign(:page_title, "Join #{company.name}")
        |> assign(:company, company)
        |> assign(:token, token)
        |> assign(:form, form)
        |> assign(:invalid_token, false)
      else
        socket
        |> assign(:page_title, "Invalid invite link")
        |> assign(:company, nil)
        |> assign(:token, token)
        |> assign(:form, nil)
        |> assign(:invalid_token, true)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <%= if @invalid_token do %>
        <div class="text-center">
          <h1 class="text-2xl font-bold text-red-600">Invalid invite link</h1>
          <p class="mt-2 text-base-content/70">
            This invite link is not valid. Please ask the company for a new one.
          </p>
          <.link
            navigate={~p"/"}
            class="mt-6 inline-block rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary/90"
          >
            Go home
          </.link>
        </div>
      <% else %>
        <div class="text-center">
          <h1 class="text-2xl font-bold">Join {@company.name}</h1>
          <p class="mt-2 text-base-content/70">
            Enter a username to join the company workspace.
          </p>
        </div>

        <.form
          for={@form}
          id="join-form"
          action={~p"/join/#{@token}/session"}
          class="mt-8 mx-auto max-w-sm space-y-4"
        >
          <.input field={@form[:username]} type="text" label="Username" required />
          <button type="submit" class="btn btn-primary w-full">
            Join
          </button>
        </.form>
      <% end %>
    </Layouts.app>
    """
  end
end
