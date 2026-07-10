defmodule Sona.Accounts.UserTest do
  use Sona.DataCase, async: true

  alias Sona.Accounts.{Company, User}

  describe "changeset/2" do
    test "validates username is required" do
      changeset = User.changeset(%User{}, %{})
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates username length" do
      changeset = User.changeset(%User{}, %{username: String.duplicate("a", 51)})
      assert %{username: ["should be at most 50 character(s)"]} = errors_on(changeset)
    end

    test "normalizes mixed-case username and accepts it" do
      changeset = User.changeset(%User{}, %{username: "TestUser"})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :username) == "testuser"
    end

    test "validates username format prevents special characters" do
      changeset = User.changeset(%User{}, %{username: "user name!"})
      assert %{username: _} = errors_on(changeset)
    end

    test "normalizes username to lowercase" do
      changeset = User.changeset(%User{}, %{username: "TestUser"})
      assert Ecto.Changeset.get_change(changeset, :username) == "testuser"
    end

    test "sets display_name to username when not provided" do
      changeset = User.changeset(%User{}, %{username: "testuser"})
      assert Ecto.Changeset.get_change(changeset, :display_name) == "testuser"
    end

    test "does not override display_name when provided" do
      changeset = User.changeset(%User{}, %{username: "testuser", display_name: "Test User"})
      assert Ecto.Changeset.get_change(changeset, :display_name) == "Test User"
    end

    test "stores mixed-case username as lowercase in the database" do
      company = Repo.insert!(%Company{name: "Test Hotel", invite_token: "tok1"})

      changeset =
        User.changeset(%User{company_id: company.id}, %{
          username: "TestUser",
          display_name: "Test"
        })

      assert {:ok, user} = Repo.insert(changeset)
      assert user.username == "testuser"
    end

    test "duplicate username in same company fails" do
      company = Repo.insert!(%Company{name: "Test Hotel", invite_token: "tok1"})
      Repo.insert!(%User{company_id: company.id, username: "alice", display_name: "Alice"})

      changeset =
        User.changeset(%User{company_id: company.id}, %{username: "alice", display_name: "Alice"})

      assert {:error, _} = Repo.insert(changeset)
    end

    test "same username in two companies succeeds" do
      company_a = Repo.insert!(%Company{name: "Company A", invite_token: "tok_a"})
      company_b = Repo.insert!(%Company{name: "Company B", invite_token: "tok_b"})

      assert {:ok, _} =
               Repo.insert(
                 User.changeset(%User{company_id: company_a.id}, %{
                   username: "alice",
                   display_name: "Alice"
                 })
               )

      assert {:ok, _} =
               Repo.insert(
                 User.changeset(%User{company_id: company_b.id}, %{
                   username: "alice",
                   display_name: "Alice"
                 })
               )
    end
  end
end
