defmodule ParselyWeb.TwoFactorAuthLive do
  use ParselyWeb, :live_view

  alias Parsely.Accounts
  alias NimbleTOTP

  def mount(_params, _session, socket) do
    _user = socket.assigns.current_user

    # Generate a 6-digit OTP
    secret = NimbleTOTP.secret()
    otp = NimbleTOTP.verification_code(secret, time: :os.system_time(:second))

    # Store the OTP in the session for verification
    socket = assign(socket,
      otp: otp,
      secret: secret,
      error_message: nil
    )

    {:ok, socket}
  end

  def handle_event("verify", %{"otp" => input_otp}, socket) do
    user = socket.assigns.current_user
    expected_otp = socket.assigns.otp

    if input_otp == expected_otp do
      # Generate a trusted device token
      token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      # Create trusted device record
              case Accounts.create_trusted_device(user, token, socket.assigns.conn) do
          {:ok, _device} ->
            # Redirect to dashboard
            {:noreply, redirect(socket, to: ~p"/dashboard")}

        {:error, _changeset} ->
          {:noreply, assign(socket, error_message: "Failed to create trusted device")}
      end
    else
      {:noreply, assign(socket, error_message: "Invalid verification code")}
    end
  end

  def handle_event("resend", _params, socket) do
    # Generate a new OTP
    secret = NimbleTOTP.secret()
    otp = NimbleTOTP.verification_code(secret, time: :os.system_time(:second))

    {:noreply, assign(socket, otp: otp, secret: secret, error_message: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Two-Factor Authentication
        <:subtitle>Enter the verification code to continue</:subtitle>
      </.header>

      <.simple_form for={%{}} phx-submit="verify" class="space-y-6">
        <.input
          field={%{name: "otp", type: "text"}}
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

      <div class="mt-8 text-center text-sm text-zinc-600">
        <p>For security, this device will be remembered for 30 days.</p>
      </div>
    </div>
    """
  end
end
