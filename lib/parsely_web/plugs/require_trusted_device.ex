defmodule ParselyWeb.Plugs.RequireTrustedDevice do
  import Plug.Conn
  import Phoenix.Controller
  use ParselyWeb, :verified_routes
  alias Parsely.Accounts

  @cookie "parsely_tdid"

  def init(opts), do: opts

  def call(%{assigns: %{current_user: user}} = conn, _opts) when not is_nil(user) do
    IO.puts("=== REQUIRE TRUSTED DEVICE PLUG ===")
    IO.puts("User: #{user.email}")
    IO.puts("Cookie value: #{inspect(conn.req_cookies[@cookie])}")

    case conn.req_cookies[@cookie] do
      nil ->
        IO.puts("No cookie found, challenging")
        challenge(conn)
      token ->
        IO.puts("Token found: #{token}")
        trusted = Accounts.device_trusted?(user, token, conn)
        IO.puts("Device trusted: #{trusted}")
        if trusted, do: conn, else: challenge(conn)
    end
  end
  def call(conn, _), do: conn

  defp challenge(conn) do
    conn
    |> redirect(to: ~p"/2fa/challenge")
    |> halt()
  end
end
