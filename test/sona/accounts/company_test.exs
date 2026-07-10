defmodule Sona.Accounts.CompanyTest do
  use Sona.DataCase, async: true

  alias Sona.Accounts.Company

  describe "changeset/2" do
    test "validates name is required" do
      changeset = Company.changeset(%Company{}, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name is present" do
      changeset = Company.changeset(%Company{}, %{name: "Test Hotel"})
      assert changeset.valid?
    end
  end
end
