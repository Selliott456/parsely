defmodule Parsely.Repo.Migrations.UpdatePhoneFieldsInBusinessCards do
  use Ecto.Migration

  def change do
    alter table(:business_cards) do
      add :primary_phone, :string
      add :secondary_phone, :string
      remove :phone, :string
    end
  end
end
