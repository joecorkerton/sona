defmodule SonaWeb.HomeLive do
  use SonaWeb, :live_view

  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok, push_navigate(socket, to: "/chats")}
    else
      form = to_form(%{"company_name" => "", "username" => ""})
      {:ok, assign(socket, form: form)}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-md px-0 py-8 sm:py-12">
        <div class="rounded-xl border border-base-300 bg-base-100 p-6 sm:p-8 shadow-sm">
          <p class="text-center text-2xl font-semibold tracking-tight text-primary mb-2">
            Sona.
          </p>
          <h1 class="text-2xl font-bold text-center text-base-content mb-8">
            Create your workplace
          </h1>
          <form action="/session" method="POST" id="new-company-form" class="space-y-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <.input field={@form[:company_name]} type="text" label="Company name" required />
            <.input field={@form[:username]} type="text" label="Your username" required />
            <.button type="submit" variant="primary" class="w-full">
              Create workspace
            </.button>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
