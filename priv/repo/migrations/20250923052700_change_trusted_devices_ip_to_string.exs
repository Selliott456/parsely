defmodule Parsely.Repo.Migrations.ChangeTrustedDevicesIpToString do
  use Ecto.Migration

  def change do
    alter table(:trusted_devices) do
      modify :ip, :string
    end
  end
end
