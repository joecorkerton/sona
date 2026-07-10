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
      <div class="mx-auto max-w-md px-4 py-12">
        <h1 class="text-2xl font-bold text-center mb-8">Create your workplace</h1>
        <form action="/session" method="POST" id="new-company-form" class="space-y-4">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <.input field={@form[:company_name]} type="text" label="Company name" required />
          <.input field={@form[:username]} type="text" label="Your username" required />
          <button type="submit" class="btn btn-primary w-full">Create workspace</button>
        </form>
      </div>
    </Layouts.app>
    """
  end
end
