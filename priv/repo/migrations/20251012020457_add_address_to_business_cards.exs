defmodule Parsely.Repo.Migrations.AddAddressToBusinessCards do
  use Ecto.Migration

  def change do
    alter table(:business_cards) do
      add :address, :string
    end
  end
end
