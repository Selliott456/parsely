defmodule Parsely.Accounts.TrustedDevice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trusted_devices" do
    field :token_hash, :binary
    field :user_agent, :string
    field :ip, :string
    field :last_seen_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec

    belongs_to :user, Parsely.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(trusted_device, attrs) do
    trusted_device
    |> cast(attrs, [:token_hash, :user_agent, :ip, :last_seen_at, :expires_at, :user_id])
    |> validate_required([:token_hash, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  def create_changeset(trusted_device, attrs) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, 60 * 60 * 24 * 30, :second)

    trusted_device
    |> cast(attrs, [:token_hash, :user_agent, :ip, :user_id])
    |> validate_required([:token_hash, :user_id])
    |> put_change(:last_seen_at, now)
    |> put_change(:expires_at, expires_at)
    |> foreign_key_constraint(:user_id)
  end
end
