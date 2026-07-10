# Seeds — demo data for development.
#
# Creates a demo company with a fixed invite token, a handful of users,
# the default General room plus an extra group, and sample messages.
#
#     mix run priv/repo/seeds.exs
#

import Ecto.Query

alias Sona.Accounts
alias Sona.Chats
alias Sona.Repo

# 1. Create the demo company with a pinned invite token
IO.puts("Creating demo company…")

{:ok, {company, alice}} =
  Accounts.create_company(%{
    name: "Demo Hotel",
    username: "alice",
    display_name: "Alice",
    invite_token: "demo-hotel"
  })

# 2. Ensure the General room exists
IO.puts("Setting up General room…")
{:ok, general_room} = Chats.ensure_default_room(company, alice)

# 3. Create additional users
IO.puts("Creating users…")

{:ok, bob} =
  Accounts.get_or_create_user(company, "bob")

# Give bob a display name
bob
|> Ecto.Changeset.change(%{display_name: "Bob"})
|> Repo.update!()

{:ok, charlie} =
  Accounts.get_or_create_user(company, "charlie")

charlie
|> Ecto.Changeset.change(%{display_name: "Charlie"})
|> Repo.update!()

# 4. Add bob and charlie to General
{:ok, _bob_membership} = Chats.add_to_general(bob)
{:ok, _charlie_membership} = Chats.add_to_general(charlie)

# 5. Create an extra group room
IO.puts("Creating extra group room…")
{:ok, lounge_room} = Chats.create_group_room(alice, %{name: "Staff Lounge"})

# Add bob and charlie to the lounge room
Repo.insert!(
  %Sona.Chat.Membership{}
  |> Sona.Chat.Membership.changeset(%{})
  |> Ecto.Changeset.put_change(:room_id, lounge_room.id)
  |> Ecto.Changeset.put_change(:user_id, bob.id)
)

Repo.insert!(
  %Sona.Chat.Membership{}
  |> Sona.Chat.Membership.changeset(%{})
  |> Ecto.Changeset.put_change(:room_id, lounge_room.id)
  |> Ecto.Changeset.put_change(:user_id, charlie.id)
)

# 6. Seed sample messages
IO.puts("Seeding sample messages…")

sample_messages = [
  %{body: "Welcome to Demo Hotel! 🎉", user: alice, room: general_room},
  %{body: "Hey everyone! Excited to be here.", user: bob, room: general_room},
  %{body: "Hi Bob! Let's make this a great place to work.", user: alice, room: general_room},
  %{body: "When is the next team meeting?", user: charlie, room: general_room},
  %{body: "I'll set one up for next Monday at 10am.", user: alice, room: general_room},
  %{
    body: "First shift starts at 8am tomorrow — who's on reception?",
    user: alice,
    room: lounge_room
  },
  %{body: "I've got the morning shift covered!", user: bob, room: lounge_room},
  %{
    body: "Anyone tried the new coffee machine in the break room?",
    user: charlie,
    room: lounge_room
  }
]

Enum.each(sample_messages, fn %{body: body, user: user, room: room} ->
  Chats.send_message(room, user, %{body: body})
end)

user_count = Repo.aggregate(from(u in Sona.Accounts.User), :count, :id)

IO.puts("""
\nSeeds complete! You can log in with:
  Invite URL: #{SonaWeb.Endpoint.url()}/join/demo-hotel
  Usernames:  alice, bob, charlie
  Total users: #{user_count}
""")
