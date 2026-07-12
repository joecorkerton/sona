defmodule Sona.Guide.Prompt do
  @moduledoc """
  Builds a single system prompt string for the AI shift guide.

  The prompt establishes a persona and goal, injects the user's shift data
  (previous shifts, upcoming shifts, overtime, site demand), and sets output
  rules for the LLM reply.

  This is a **pure function** — no network, no Repo, no LLM call.
  """

  @doc """
  Builds a system prompt string for the given `user` and `shift_data` map.

  `shift_data` is expected to have the shape returned by
  `Sona.Guide.ShiftData.for/1`:

      %{
        previous_shifts: [...],
        upcoming_shifts: [...],
        overtime: [...],
        demand: %{...},
        site: %Company{}
      }

  Returns a single string containing the persona, injected data, and output
  rules.

  ## Examples

      iex> company = %Sona.Accounts.Company{name: "Demo Hotel"}
      iex> user = %Sona.Accounts.User{display_name: "Alice", company: company}
      iex> data = %{previous_shifts: [], upcoming_shifts: [], overtime: [],
      ...>         demand: %{occupancy_rate: 0.9, events: [], staffing_notes: ""},
      ...>         site: company}
      iex> prompt = Prompt.build(user, data)
      iex> assert prompt =~ "PREVIOUS SHIFTS"
      iex> assert prompt =~ "Demo Hotel"
  """
  @spec build(Sona.Accounts.User.t(), map()) :: String.t()
  def build(%{display_name: display_name, company: company}, shift_data) do
    site_name = company && company.name

    sections = [
      header(display_name, site_name),
      previous_shifts_section(shift_data[:previous_shifts]),
      upcoming_shifts_section(shift_data[:upcoming_shifts]),
      overtime_section(shift_data[:overtime]),
      demand_section(shift_data[:demand]),
      output_rules()
    ]

    sections
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp header(display_name, site_name) do
    label = site_name || "your company"

    """
    SYSTEM: You are Sona Guide, an AI shift assistant for #{label}.
    Your goal is to help #{display_name} prepare for their upcoming shift.
    Be concise, supportive, and practical. Speak directly to #{display_name}.
    """
  end

  defp previous_shifts_section(nil), do: nil
  defp previous_shifts_section([]), do: nil

  defp previous_shifts_section(previous_shifts) do
    lines =
      Enum.map(previous_shifts, fn shift ->
        "- [PREVIOUS SHIFT] #{format_date(shift[:date])} #{shift[:start_time]}-#{shift[:end_time]}" <>
          " | Role: #{shift[:role]} — #{shift[:notes]}"
      end)

    "PREVIOUS SHIFTS:\n#{Enum.join(lines, "\n")}"
  end

  defp upcoming_shifts_section(nil), do: nil
  defp upcoming_shifts_section([]), do: nil

  defp upcoming_shifts_section(upcoming_shifts) do
    lines =
      Enum.map(upcoming_shifts, fn shift ->
        "- [UPCOMING SHIFT] #{format_date(shift[:date])} #{shift[:start_time]}-#{shift[:end_time]}" <>
          " | Role: #{shift[:role]} — #{shift[:notes]}"
      end)

    "UPCOMING SHIFTS:\n#{Enum.join(lines, "\n")}"
  end

  defp overtime_section(nil), do: nil
  defp overtime_section([]), do: nil

  defp overtime_section(overtime) do
    lines =
      Enum.map(overtime, fn entry ->
        "- [OVERTIME] #{format_date(entry[:date])} — #{entry[:hours]}h — #{entry[:reason]}"
      end)

    "OVERTIME:\n#{Enum.join(lines, "\n")}"
  end

  defp demand_section(nil), do: nil

  defp demand_section(demand) when demand == %{}, do: nil

  defp demand_section(demand) do
    events =
      (demand[:events] || [])
      |> Enum.map_join("\n", fn event ->
        "- [EVENT] #{event[:name]} on #{format_date(event[:date])} — #{event[:impact]}"
      end)

    occupancy =
      if demand[:occupancy_rate],
        do: "Occupancy rate: #{demand[:occupancy_rate] * 100}%",
        else: ""

    notes = demand[:staffing_notes] || ""

    text =
      """
      DEMAND / SITE CONTEXT:
      #{occupancy}
      #{if events != "", do: "\nUpcoming events:\n#{events}"}
      #{if notes != "", do: "\nStaffing notes: #{notes}"}
      """
      |> String.trim()

    if text == "DEMAND / SITE CONTEXT:", do: nil, else: text
  end

  defp output_rules do
    """
    OUTPUT RULES:
    - Keep responses concise (2–4 sentences unless asked for detail).
    - Always reference the shift data above when giving advice.
    - Do not ask the user for information you already have in the data above.
    - Be supportive and encouraging — the goal is to help the user feel prepared.
    - If the user asks something outside your scope, politely redirect to a manager.
    """
  end

  defp format_date(nil), do: "N/A"

  defp format_date(%Date{} = d) do
    Date.to_string(d)
  end

  defp format_date(other), do: to_string(other)
end
