defmodule Parsely.Repo.Migrations.AddNotesToBusinessCards do
  use Ecto.Migration

  def change do
    alter table(:business_cards) do
      add :notes, :json, default: "[]"
    end
  end
end
