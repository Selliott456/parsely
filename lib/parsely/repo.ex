defmodule Parsely.Repo do
  use Ecto.Repo,
    otp_app: :parsely,
    adapter: Ecto.Adapters.Postgres
end
