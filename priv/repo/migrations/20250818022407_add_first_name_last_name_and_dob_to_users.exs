defmodule Parsely.Repo.Migrations.AddFirstNameLastNameAndDobToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :date_of_birth, :date
    end

    create index(:users, [:first_name, :last_name])
  end
end
