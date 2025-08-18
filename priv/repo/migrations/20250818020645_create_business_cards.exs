defmodule Parsely.Repo.Migrations.CreateBusinessCards do
  use Ecto.Migration

  def change do
    create table(:business_cards) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string
      add :email, :string
      add :phone, :string
      add :company, :string
      add :position, :string
      add :image_url, :string
      add :ocr_data, :map
      add :is_virtual, :boolean, default: false
      timestamps()
    end

    create index(:business_cards, [:user_id])
    create index(:business_cards, [:email])
    create index(:business_cards, [:user_id, :email])

    create table(:business_card_notes) do
      add :business_card_id, references(:business_cards, on_delete: :delete_all), null: false
      add :note, :text, null: false
      add :date_added, :utc_datetime_usec, null: false
      timestamps()
    end

    create index(:business_card_notes, [:business_card_id])
  end
end
