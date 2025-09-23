defmodule ParselyWeb.TwoFactorAuthLive do
  use ParselyWeb, :live_view

  alias Parsely.Accounts
  alias Parsely.Accounts.UserNotifier
  alias NimbleTOTP

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Generate a 6-digit OTP
    secret = NimbleTOTP.secret()
    otp = NimbleTOTP.verification_code(secret, time: :os.system_time(:second))

    # Send OTP via email
    UserNotifier.deliver_2fa_code(user, otp)

    # Create a form for the OTP input
    form = to_form(%{"otp" => ""}, as: "otp")

    # Store the OTP in the session for verification
    socket = assign(socket,
      otp: otp,
      secret: secret,
      error_message: nil,
      form: form,
      success_message: "Verification code sent to your email"
    )

    {:ok, socket}
  end


  def handle_event("verify", %{"otp" => %{"otp" => input_otp}}, socket) do
    user = socket.assigns.current_user
    expected_otp = socket.assigns.otp

    if input_otp == expected_otp do
      # Generate a trusted device token
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      # Create trusted device record (using LiveView-specific function)
      case Accounts.create_trusted_device_from_liveview(user, token) do
        {:ok, _device} ->
          # Redirect to a controller endpoint that will set the cookie and redirect to dashboard
          {:noreply, redirect(socket, to: ~p"/auth/trusted-device?token=#{token}")}

        {:error, _changeset} ->
          {:noreply, assign(socket, error_message: "Failed to create trusted device")}
      end
    else
      {:noreply, assign(socket, error_message: "Invalid verification code")}
    end
  end

  def handle_event("resend", _params, socket) do
    user = socket.assigns.current_user

    # Generate a new OTP
    secret = NimbleTOTP.secret()
    otp = NimbleTOTP.verification_code(secret, time: :os.system_time(:second))

    # Send new OTP via email
    UserNotifier.deliver_2fa_code(user, otp)

    # Create a new form
    form = to_form(%{"otp" => ""}, as: "otp")

    {:noreply, assign(socket, otp: otp, secret: secret, error_message: nil, form: form, success_message: "New verification code sent to your email")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Two-Factor Authentication
        <:subtitle>Enter the verification code to continue</:subtitle>
      </.header>

      <.simple_form for={@form} phx-submit="verify" class="space-y-6">
        <.input
          field={@form[:otp]}
          label="Verification Code"
          placeholder="Enter 6-digit code"
          maxlength="6"
          pattern="[0-9]{6}"
          required
        />

        <:actions>
          <.button_primary phx-disable-with="Verifying..." class="w-full">
            Verify Device
          </.button_primary>
        </:actions>
      </.simple_form>

      <div class="mt-6 text-center">
        <.button_secondary
          type="button"
          phx-click="resend"
          class="text-sm"
        >
          Resend Code
        </.button_secondary>
      </div>

      <%= if @error_message do %>
        <div class="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-sm text-red-600"><%= @error_message %></p>
        </div>
      <% end %>

      <%= if @success_message do %>
        <div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-lg">
          <p class="text-sm text-green-600"><%= @success_message %></p>
        </div>
      <% end %>

      <div class="mt-8 text-center text-sm text-zinc-600">
        <p>For security, this device will be remembered for 30 days.</p>
      </div>

      <!-- Development: Show the OTP for testing -->
      <%= if Application.get_env(:parsely, :dev_routes) do %>
        <div class="mt-6 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
          <p class="text-sm text-yellow-800 font-medium">Development Mode</p>
          <p class="text-sm text-yellow-700 mt-1">Your verification code is: <span class="font-mono font-bold text-lg"><%= @otp %></span></p>
        </div>
      <% end %>
    </div>
    """
  end
end
