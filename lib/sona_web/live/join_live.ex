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
      <div class="mx-auto w-full max-w-md px-0 py-8 sm:py-12">
        <div class="rounded-xl border border-base-300 bg-base-100 p-6 sm:p-8 shadow-sm">
          <%= if @invalid_token do %>
            <p class="text-center text-2xl font-semibold tracking-tight text-primary mb-2">
              Sona.
            </p>
            <div class="text-center">
              <h1 class="text-2xl font-bold text-error">Invalid invite link</h1>
              <p class="mt-2 text-base-content/70">
                This invite link is not valid. Please ask the company for a new one.
              </p>
              <.button navigate={~p"/"} variant="primary" class="mt-6">
                Go home
              </.button>
            </div>
          <% else %>
            <p class="text-center text-2xl font-semibold tracking-tight text-primary mb-2">
              Sona.
            </p>
            <div class="text-center">
              <h1 class="text-2xl font-bold text-base-content">Join {@company.name}</h1>
              <p class="mt-2 text-base-content/70">
                Enter a username to join the company workspace.
              </p>
            </div>

            <.form
              for={@form}
              id="join-form"
              action={~p"/join/#{@token}/session"}
              class="mt-8 space-y-4"
            >
              <.input field={@form[:username]} type="text" label="Username" required />
              <.button type="submit" variant="primary" class="w-full">
                Join
              </.button>
            </.form>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
