defmodule ParselyWeb.TrustedDeviceController do
  use ParselyWeb, :controller

  def set_trusted_device(conn, %{"token" => token}) do
    IO.puts("=== TRUSTED DEVICE CONTROLLER ===")
    IO.puts("Token received: #{token}")
    IO.puts("Setting cookie: parsely_tdid")

    conn
    |> put_resp_cookie("parsely_tdid", token, max_age: 60 * 60 * 24 * 30, http_only: true, secure: false)
    |> redirect(to: ~p"/dashboard")
  end
end
