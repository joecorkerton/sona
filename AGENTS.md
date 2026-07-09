This is a Phoenix LiveView web application (`Sona` / `SonaWeb`) backed by PostgreSQL and Tailwind CSS.

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- HTTP client: use the bundled `:req` (`Req`) library. **Avoid** `:httpoison`, `:tesla`, and `:httpc`
- Date/time: use the stdlib (`Time`, `Date`, `DateTime`, `Calendar`). Don't add deps for this (except `date_time_parser` if you need parsing)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names end in `?`; don't start them with `is_` (reserved for guards)

## Elixir

- Elixir lists use `Enum.at/2` (or pattern matching), not `mylist[i]` index syntax
- Variables are immutable but rebound.**Always** rebind the *result* of `if`/`case`/`cond` blocks you care about — you cannot rebind inside:

      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- `if/else` exists but there's **no** `else if` / `elsif`. Use `cond` or `case`
- Never nest multiple modules in one file (cyclic deps)
- Never use `struct[:field]` on structs — use `struct.field` or `Ecto.Changeset.get_field/2`
- OTP primitives like `DynamicSupervisor`/`Registry` need a name in the child spec, e.g. `{DynamicSupervisor, name: Sona.MySup}`
- Use `Task.async_stream(coll, fn, timeout: :infinity)` for concurrent enumeration with back-pressure

### Mix

- Debug tests: `mix test path/to/test.exs` or `mix test --failed`
- Avoid `mix deps.clean --all`
- Use `mix ecto.gen.migration name_with_underscores` for migrations

## Ecto

- **Always** preload associations you access in templates (e.g. `message.user.email`)
- `import Ecto.Query` in `seeds.exs`
- Schema text columns still use `:string`, i.e. `field :name, :string`
- `validate_number/2` has no `:allow_nil` option (validations skip nil by default)
- Access changeset fields with `Ecto.Changeset.get_field/2`
- Programmatically-set fields (e.g. `user_id`) must **not** be in `cast` — set them explicitly on the struct

## Phoenix

- Router `scope` auto-aliases contained routes. Don't add your own `alias` for routes:

      scope "/admin", SonaWeb.Admin do
        live "/users", UserLive, :index   # -> SonaWeb.Admin.UserLive
      end

- `Phoenix.View` is gone — don't use it
- `<.flash_group>` only belongs in the `Layouts` module (`sona_web/components/layouts.ex`)
- Use the `<.icon name="hero-x-mark" .../>` component for icons — never `Heroicons` modules directly
- Use the imported `<.input>` component for form inputs. If you override its `class`, no defaults are inherited — you must fully style it

## LiveView

- LiveViews are named `SonaWeb.<Thing>Live`. The default `:browser` scope is already aliased to `SonaWeb`, so routes are just `live "/thing", ThingLive`
- **Always** start LiveView templates with `<Layouts.app flash={@flash} ...>`. Pass `current_scope` through; no `current_scope` errors always mean a missing `live_session` / missing `current_scope` pass-through
- Never use `live_redirect`/`live_patch`. Use `<.link navigate={...}>` / `<.link patch={...}>` in templates, and `push_navigate` / `push_patch` in LiveViews
- Avoid `LiveComponent`s unless you have a specific need
- Never write raw `<script>` tags in HEEx. Use colocated hooks (`:type={Phoenix.LiveView.ColocatedHook}`, names **must** start with `.`) or external hooks in `assets/js/` passed to `LiveSocket`
- With `phx-hook="MyHook"` that manages its own DOM, also set `phx-update="ignore"` and give the element a unique `id`
- `push_event/3` returns the socket — always rebind it:

      socket = push_event(socket, "my_event", %{...})

### Streams

- **Always** use LiveView streams (not lists) for collections. Append `stream(socket, :messages, [m])`, reset `stream(..., reset: true)`, prepend `at: -1`, delete via `stream_delete`
- Template needs `phx-update="stream"` + a DOM id on the parent, and consumes `@streams.name`, using each id as the child DOM id
- Streams aren't enumerable. To filter/refresh, refetch and re-stream with `reset: true`
- Streams have no count/empty state. Track count in a separate assign; for empty state use Tailwind `hidden only:block`

      <div id="messages" phx-update="stream">
        <div class="hidden only:block">No messages yet</div>
        <div :for={{id, msg} <- @streams.messages} id={id}>{msg.text}</div>
      </div>

- When an assign changes content inside streamed items, `stream_insert` them along with the assign
- Never use `phx-update="append"`/`"prepend"`

### Forms

- Build forms with `to_form/2` in the LiveView (`assign(socket, form: to_form(params))`), access via `@form[:field]` in templates
- Always give forms a unique DOM id (e.g. `id="product-form"`) — these IDs drive tests
- Never pass a raw changeset to `<.form>` or access `@changeset[:field]` in templates — drive everything from the form assign

      <.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>

### Tests

- Use `Phoenix.LiveViewTest` + `LazyHTML`
- Assert on elements, never raw HTML: `assert has_element?(view, "#my-form")`
- Reference the IDs you put in templates. Prefer element presence over text content
- `render_submit/2` / `render_change/2` drive forms
- To debug selector failures, filter with `LazyHTML` and `IO.inspect` the matches

## HEEx

- Templates use `~H` or `.html.heex`, never `~E`
- Never use `Phoenix.HTML.form_for` / `inputs_for` — use `Phoenix.Component.form/1` / `inputs_for/1`
- Never `<% Enum.each %>` for rendering — use `<%= for item <- @coll do %>`
- Attribute interpolation uses `{...}`, block constructs in bodies use `<%= ... %>`:

      <div id={@id}>
        {@assign}
        <%= if @flag do %>{@other}<% end %>
      </div>

Never put `if`/`end` inside `{...}`, and never `id="<%= ... %>"`.

- Class attrs with multiple values use list syntax, parens around `if`:

      <a class={[
        "px-2 text-white",
        @flag && "py-5",
        if(@cond, do: "border-red-500", else: "border-blue-100")
      ]}>

- HTML comments use `<%!-- comment --%>`
- For literal `{}` in `<pre>`/`<code>`, annotate the parent with `phx-no-curly-interpolation`

## CSS / JS

- Tailwind v4 — no `tailwind.config.js`. Maintain this import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/sona_web";

- Never use `@apply` in raw CSS — write out the Tailwind classes
- No daisyUI; write your own Tailwind components
- Only `app.js` and `app.css` are bundled. Import vendor deps into those files — never reference external `src`/`href` in layouts, and never inline `<script>` tags in templates

## Tests (general)

- `start_supervised!/1` for processes in tests (auto cleanup)
- Avoid `Process.sleep/1` / `Process.alive?/1`. Use `Process.monitor/1` + `assert_receive {:DOWN, ^ref, ...}` for teardown, and `_ = :sys.get_state(pid)` to sync before the next call