defmodule Parsely.Repo.Migrations.CreateTrustedDevicesAndOtps do
  use Ecto.Migration

  def change do
      create table(:trusted_devices) do
        add :user_id, references(:users, on_delete: :delete_all), null: false
        add :token_hash, :binary, null: false
        add :user_agent, :text
        add :ip, :inet
        add :last_seen_at, :utc_datetime_usec
        add :expires_at, :utc_datetime_usec
        timestamps()
      end
      create index(:trusted_devices, [:user_id])
      create unique_index(:trusted_devices, [:token_hash])

      create table(:login_otps) do
        add :user_id, references(:users, on_delete: :delete_all), null: false
        add :code_hash, :binary, null: false
        add :purpose, :string, null: false # "login"
        add :expires_at, :utc_datetime_usec, null: false
        timestamps(updated_at: false)
      end
      create index(:login_otps, [:user_id])
  end
end
