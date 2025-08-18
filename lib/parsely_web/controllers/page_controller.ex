defmodule ParselyWeb.PageController do
  use ParselyWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      # Redirect authenticated users to dashboard
      redirect(conn, to: ~p"/dashboard")
    else
      # The home page is often custom made,
      # so skip the default app layout.
      render(conn, :home, layout: false)
    end
  end
end
