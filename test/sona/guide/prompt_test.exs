defmodule Sona.Guide.PromptTest do
  use ExUnit.Case, async: true

  alias Sona.Accounts.Company
  alias Sona.Guide.{Prompt, ShiftData}

  describe "ShiftData.for/1" do
    setup do
      %{company: %Company{id: Ecto.UUID.generate(), name: "Demo Hotel"}}
    end

    test "returns a map with the expected keys", %{company: company} do
      user = build_user("alice", company)
      data = ShiftData.for(user)

      assert Map.has_key?(data, :previous_shifts)
      assert Map.has_key?(data, :upcoming_shifts)
      assert Map.has_key?(data, :overtime)
      assert Map.has_key?(data, :demand)
      assert Map.has_key?(data, :site)
      assert data.site == company
    end

    test "returns previous shifts for alice", %{company: company} do
      user = build_user("alice", company)
      data = ShiftData.for(user)

      assert length(data.previous_shifts) == 3
      assert %{role: "Front Desk"} = hd(data.previous_shifts)
    end

    test "returns previous shifts for bob", %{company: company} do
      user = build_user("bob", company)
      data = ShiftData.for(user)

      assert length(data.previous_shifts) == 3
      assert %{role: "Housekeeping"} = hd(data.previous_shifts)
    end

    test "returns previous shifts for charlie", %{company: company} do
      user = build_user("charlie", company)
      data = ShiftData.for(user)

      assert length(data.previous_shifts) == 3
      first = hd(data.previous_shifts)
      assert first.role =~ "Kitchen"
    end

    test "returns upcoming shifts for alice", %{company: company} do
      user = build_user("alice", company)
      data = ShiftData.for(user)

      assert length(data.upcoming_shifts) == 2
      assert %{role: "Front Desk"} = hd(data.upcoming_shifts)
    end

    test "overtime data has hours and reason", %{company: company} do
      user = build_user("alice", company)
      data = ShiftData.for(user)

      assert length(data.overtime) == 2
      entry = hd(data.overtime)
      assert is_float(entry.hours)
      assert is_binary(entry.reason)
    end

    test "demand has occupancy_rate, events, and staffing_notes", %{company: company} do
      user = build_user("alice", company)
      data = ShiftData.for(user)

      assert is_float(data.demand.occupancy_rate)
      assert is_list(data.demand.events)
      assert is_binary(data.demand.staffing_notes)
    end

    test "unknown username returns empty lists", %{company: company} do
      user = build_user("stranger", company)
      data = ShiftData.for(user)

      assert data.previous_shifts == []
      assert data.upcoming_shifts == []
      assert data.overtime == []
    end

    test "site is the user's company struct", %{company: _company} do
      other_company = %Company{id: Ecto.UUID.generate(), name: "Other Hotel"}
      user = build_user("alice", other_company)
      data = ShiftData.for(user)

      assert data.site == other_company
      assert data.site.name == "Other Hotel"
    end
  end

  describe "Prompt.build/2" do
    setup do
      company = %Company{id: Ecto.UUID.generate(), name: "Demo Hotel"}
      user = build_user("alice", company)
      shift_data = ShiftData.for(user)
      %{company: company, user: user, shift_data: shift_data}
    end

    test "returns a string", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert is_binary(prompt)
    end

    test "contains the user's display name", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "Alice"
    end

    test "contains the company name", %{company: company, user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ company.name
    end

    test "contains PREVIOUS SHIFTS marker", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "PREVIOUS SHIFTS"
    end

    test "contains UPCOMING SHIFTS marker", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "UPCOMING SHIFTS"
    end

    test "contains OVERTIME marker", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "OVERTIME"
    end

    test "contains DEMAND / SITE CONTEXT marker", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "DEMAND / SITE CONTEXT"
    end

    test "contains OUTPUT RULES marker", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "OUTPUT RULES"
    end

    test "establishes a persona and goal", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "Sona Guide"
      assert prompt =~ "shift assistant"
    end

    test "output rules are present", %{user: user, shift_data: shift_data} do
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "concise"
      assert prompt =~ "supportive"
    end

    test "handles empty shift data gracefully" do
      company = %Company{id: Ecto.UUID.generate(), name: "Demo Hotel"}
      user = build_user("new_user", company)

      empty_data = %{
        previous_shifts: [],
        upcoming_shifts: [],
        overtime: [],
        demand: %{occupancy_rate: nil, events: [], staffing_notes: ""},
        site: company
      }

      prompt = Prompt.build(user, empty_data)

      assert is_binary(prompt)
      assert prompt =~ "Sona Guide"
      assert prompt =~ "OUTPUT RULES"
      # Empty sections should not render headers
      refute prompt =~ "PREVIOUS SHIFTS"
      refute prompt =~ "UPCOMING SHIFTS"
      refute prompt =~ "OVERTIME"
      refute prompt =~ "DEMAND / SITE CONTEXT"
    end

    test "is a pure function — no network or Repo dependency", %{
      user: user,
      shift_data: shift_data
    } do
      prompt = Prompt.build(user, shift_data)
      assert is_binary(prompt)
    end

    test "handles nil company gracefully in header", %{shift_data: shift_data} do
      user = %{display_name: "Test", company: nil}
      prompt = Prompt.build(user, shift_data)
      assert prompt =~ "your company"
    end
  end

  # Helper to build a %User{} struct for testing
  defp build_user(username, company) do
    %Sona.Accounts.User{
      id: Ecto.UUID.generate(),
      username: username,
      display_name: String.capitalize(username),
      company_id: company.id,
      company: company
    }
  end
end
