defmodule Sona.AccountsTest do
  use Sona.DataCase, async: true

  alias Sona.Accounts
  alias Sona.Accounts.{Company, User}

  describe "create_company/1" do
    test "creates company with creator user in one transaction" do
      assert {:ok, {company, user}} =
               Accounts.create_company(%{name: "Test Hotel", username: "manager"})

      assert company.name == "Test Hotel"
      assert company.invite_token
      assert user.username == "manager"
      assert user.company_id == company.id
      assert user.display_name == "manager"
    end

    test "accepts optional invite_token override" do
      assert {:ok, {company, _user}} =
               Accounts.create_company(%{
                 name: "Test Hotel",
                 username: "manager",
                 invite_token: "my-custom-token"
               })

      assert company.invite_token == "my-custom-token"
    end

    test "does not create user or company when attrs are invalid" do
      assert {:error, _reason} = Accounts.create_company(%{name: "", username: "manager"})
      assert Repo.aggregate(Company, :count) == 0
      assert Repo.aggregate(User, :count) == 0
    end

    test "does not call Chat context" do
      assert {:ok, {_company, _user}} = Accounts.create_company(%{name: "H", username: "u"})
    end
  end

  describe "get_company_by_invite_token/1" do
    test "finds company by invite token" do
      {:ok, {company, _user}} =
        Accounts.create_company(%{name: "H", username: "u", invite_token: "tok"})

      assert Accounts.get_company_by_invite_token("tok").id == company.id
    end

    test "returns nil for unknown token" do
      assert Accounts.get_company_by_invite_token("nope") == nil
    end
  end

  describe "get_or_create_user/2" do
    test "creates a new user in the company" do
      {:ok, {company, _}} =
        Accounts.create_company(%{name: "H", username: "u", invite_token: "tok"})

      assert {:ok, user} = Accounts.get_or_create_user(company, "alice")
      assert user.username == "alice"
      assert user.company_id == company.id
    end

    test "returns existing user when same username in same company" do
      {:ok, {company, _}} =
        Accounts.create_company(%{name: "H", username: "u", invite_token: "tok"})

      {:ok, %{id: first_id}} = Accounts.get_or_create_user(company, "alice")

      {:ok, user} = Accounts.get_or_create_user(company, "alice")
      assert user.id == first_id
      assert Repo.aggregate(User, :count) == 2
    end

    test "same username in two companies succeeds" do
      {:ok, {company_a, _}} =
        Accounts.create_company(%{name: "A", username: "u", invite_token: "tok_a"})

      {:ok, {company_b, _}} =
        Accounts.create_company(%{name: "B", username: "u", invite_token: "tok_b"})

      assert {:ok, user_a} = Accounts.get_or_create_user(company_a, "alice")
      assert {:ok, user_b} = Accounts.get_or_create_user(company_b, "alice")

      assert user_a.id != user_b.id
      assert user_a.company_id == company_a.id
      assert user_b.company_id == company_b.id
    end

    test "concurrent same-username inserts resolve to one user" do
      {:ok, {company, _}} =
        Accounts.create_company(%{name: "H", username: "u", invite_token: "tok"})

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            {:ok, user} = Accounts.get_or_create_user(company, "alice")
            user.id
          end)
        end

      ids = Task.await_many(tasks, :infinity)
      assert ids |> Enum.uniq() |> length() == 1
      assert Repo.aggregate(User, :count) == 2
    end

    test "returns error for invalid username format" do
      {:ok, {company, _}} =
        Accounts.create_company(%{name: "H", username: "u", invite_token: "tok"})

      assert {:error, changeset} = Accounts.get_or_create_user(company, "bad username!")
      assert %{username: _} = errors_on(changeset)
    end
  end
end
