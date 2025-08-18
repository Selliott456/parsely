defmodule ParselyWeb.TrustedDeviceController do
  use ParselyWeb, :controller

  def set_cookie(conn, _params) do
    case get_session(conn, :trusted_device_token) do
      nil ->
        conn
        |> redirect(to: ~p"/business-cards")

      token ->
        conn
        |> put_resp_cookie("parsely_tdid", token,
          max_age: 60 * 60 * 24 * 30, # 30 days
          http_only: true,
          secure: false # Set to true in production with HTTPS
        )
        |> delete_session(:trusted_device_token)
        |> redirect(to: ~p"/business-cards")
    end
  end
end
