defmodule ParselyWeb.Router do
  use ParselyWeb, :router

  import ParselyWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ParselyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ParselyWeb.Plugs.SetLocale
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_trusted_device do
    plug ParselyWeb.Plugs.RequireTrustedDevice
  end

  scope "/", ParselyWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ParselyWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:parsely, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ParselyWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ParselyWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{ParselyWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # 2FA challenge route - needs to be accessible without trusted device check
  scope "/", ParselyWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user_2fa,
      on_mount: [{ParselyWeb.UserAuth, :ensure_authenticated}] do
      live "/2fa/challenge", TwoFactorAuthLive, :challenge
    end

    get "/auth/trusted-device", TrustedDeviceController, :set_trusted_device
  end

  scope "/", ParselyWeb do
    pipe_through [:browser, :require_authenticated_user, :require_trusted_device]

    live_session :require_authenticated_user,
      on_mount: [{ParselyWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/business-cards", BusinessCardLive, :index
      live "/business-cards/new", BusinessCardLive, :new
      live "/business-cards/:id", BusinessCardDetailLive, :show
      live "/scan-card", ScanCardLive, :new
    end
  end

  scope "/", ParselyWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{ParselyWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end
end
