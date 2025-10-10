defmodule ParselyWeb.Plugs.SetLocale do
  import Plug.Conn

  @locales ~w(en ja)

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = conn |> fetch_cookies() |> Map.get(:cookies, %{}) |> Map.get("locale")
    locale = normalize_locale(locale) || "en"

    Gettext.put_locale(locale)
    conn
    |> put_session(:locale, locale)
  end

  defp normalize_locale(nil), do: nil
  defp normalize_locale("ja"), do: "ja"
  defp normalize_locale("jpn"), do: "ja"
  defp normalize_locale("en"), do: "en"
  defp normalize_locale(_), do: nil
end
