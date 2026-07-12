defmodule Sona.Guide.ShiftData do
  @moduledoc """
  Temporary hardcoded sample shift, overtime, and demand data for the seeded
  users (Alice, Bob, Charlie at Demo Hotel).

  This is a POC stand-in — no `shifts` / `overtime` / `demand` tables exist.
  Data will be fetched from real tables in a later iteration.
  """

  @doc """
  Returns a map of hardcoded shift, overtime, and demand data for the given
  user.

  The returned map has the following keys:
    - `previous_shifts` — list of recent shifts the user worked
    - `upcoming_shifts` — list of upcoming shifts the guide is prepping for
    - `overtime` — list of overtime records
    - `demand` — map of site demand modelling
    - `site` — the user's `%Company{}` (read from `user.company`)

  ## Examples

      iex> ShiftData.for(%User{username: "alice", company: %Company{name: "Demo Hotel"}})
      %{previous_shifts: [...], upcoming_shifts: [...], overtime: [...],
        demand: %{...}, site: %Company{name: "Demo Hotel"}}

  """
  def for(%{username: username} = user) when is_binary(username) do
    %{
      previous_shifts: previous_shifts(username),
      upcoming_shifts: upcoming_shifts(username),
      overtime: overtime(username),
      demand: demand(),
      site: user.company
    }
  end

  defp previous_shifts("alice") do
    [
      %{
        role: "Front Desk",
        date: ~D[2026-07-08],
        start_time: ~T[07:00:00],
        end_time: ~T[15:00:00],
        notes: "Check-in rush handled smoothly"
      },
      %{
        role: "Front Desk",
        date: ~D[2026-07-06],
        start_time: ~T[07:00:00],
        end_time: ~T[15:00:00],
        notes: "Covered reception while manager in meeting"
      },
      %{
        role: "Reception",
        date: ~D[2026-07-04],
        start_time: ~T[08:00:00],
        end_time: ~T[16:00:00],
        notes: "Independence Day — quieter than expected"
      }
    ]
  end

  defp previous_shifts("bob") do
    [
      %{
        role: "Housekeeping",
        date: ~D[2026-07-08],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        notes: "Deep-cleaned 3rd floor after conference"
      },
      %{
        role: "Housekeeping",
        date: ~D[2026-07-06],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        notes: "Routine guest room turnover"
      },
      %{
        role: "Housekeeping",
        date: ~D[2026-07-04],
        start_time: ~T[10:00:00],
        end_time: ~T[16:00:00],
        notes: "Holiday schedule — half day"
      }
    ]
  end

  defp previous_shifts("charlie") do
    [
      %{
        role: "Kitchen / Line Cook",
        date: ~D[2026-07-08],
        start_time: ~T[11:00:00],
        end_time: ~T[20:00:00],
        notes: "Dinner service — fully booked dining room"
      },
      %{
        role: "Kitchen / Line Cook",
        date: ~D[2026-07-06],
        start_time: ~T[11:00:00],
        end_time: ~T[20:00:00],
        notes: "Prepped for weekend brunch menu"
      },
      %{
        role: "Kitchen / Line Cook",
        date: ~D[2026-07-05],
        start_time: ~T[12:00:00],
        end_time: ~T[21:00:00],
        notes: "Covered for sick colleague — double shift"
      }
    ]
  end

  defp previous_shifts(_username), do: []

  defp upcoming_shifts("alice") do
    [
      %{
        role: "Front Desk",
        date: ~D[2026-07-11],
        start_time: ~T[07:00:00],
        end_time: ~T[15:00:00],
        notes: "Friday — expected check-in surge"
      },
      %{
        role: "Front Desk",
        date: ~D[2026-07-12],
        start_time: ~T[08:00:00],
        end_time: ~T[16:00:00],
        notes: "Saturday — full house expected"
      }
    ]
  end

  defp upcoming_shifts("bob") do
    [
      %{
        role: "Housekeeping",
        date: ~D[2026-07-11],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00],
        notes: "Friday — expedite checkout turnovers"
      },
      %{
        role: "Housekeeping",
        date: ~D[2026-07-12],
        start_time: ~T[10:00:00],
        end_time: ~T[18:00:00],
        notes: "Saturday — deep clean common areas"
      }
    ]
  end

  defp upcoming_shifts("charlie") do
    [
      %{
        role: "Kitchen / Line Cook",
        date: ~D[2026-07-11],
        start_time: ~T[11:00:00],
        end_time: ~T[20:00:00],
        notes: "Friday dinner — banquet event"
      },
      %{
        role: "Kitchen / Line Cook",
        date: ~D[2026-07-12],
        start_time: ~T[10:00:00],
        end_time: ~T[19:00:00],
        notes: "Saturday brunch + dinner"
      }
    ]
  end

  defp upcoming_shifts(_username), do: []

  defp overtime("alice") do
    [
      %{
        date: ~D[2026-07-06],
        hours: 1.5,
        reason: "Covered reception while manager attended emergency meeting"
      },
      %{
        date: ~D[2026-07-01],
        hours: 2.0,
        reason: "Helped train new front desk hire"
      }
    ]
  end

  defp overtime("bob") do
    [
      %{
        date: ~D[2026-07-08],
        hours: 1.0,
        reason: "Stayed late to finish conference floor cleanup"
      },
      %{
        date: ~D[2026-07-04],
        hours: 0.5,
        reason: "Half-day holiday — no overtime logged"
      }
    ]
  end

  defp overtime("charlie") do
    [
      %{
        date: ~D[2026-07-05],
        hours: 4.0,
        reason: "Covered sick colleague — double shift"
      },
      %{
        date: ~D[2026-07-01],
        hours: 1.0,
        reason: "Late service due to large walk-in party"
      }
    ]
  end

  defp overtime(_username), do: []

  defp demand do
    %{
      occupancy_rate: 0.92,
      events: [
        %{
          name: "Annual Hospitality Expo",
          date: ~D[2026-07-11],
          impact: "higher check-in volume expected throughout afternoon"
        },
        %{
          name: "Weekend Wedding Reception",
          date: ~D[2026-07-12],
          impact: "banquet service, increased dinner covers"
        }
      ],
      staffing_notes: "Weekend is near full capacity. Ensure all hands on deck."
    }
  end
end
