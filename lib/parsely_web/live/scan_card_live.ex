defmodule ParselyWeb.ScanCardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Scan Business Card",
       photo_data: nil,
       is_capturing: false,
       form: to_form(BusinessCards.change_business_card(%BusinessCard{}))
     )}
  end

  def handle_event("start-camera", _params, socket) do
    {:noreply, assign(socket, is_capturing: true)}
  end

  def handle_event("photo-captured", %{"data" => photo_data}, socket) do
    # Here you would typically:
    # 1. Upload the photo to S3
    # 2. Send it to OCR service
    # 3. Extract the data

    # For now, we'll simulate OCR results
    ocr_results = %{
      "name" => "John Doe",
      "email" => "john.doe@example.com",
      "phone" => "+1 (555) 123-4567",
      "company" => "Example Corp",
      "position" => "Software Engineer"
    }

    changeset =
      socket.assigns.form.source
      |> BusinessCards.change_business_card(ocr_results)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:photo_data, photo_data)
     |> assign(:is_capturing, false)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("retake-photo", _params, socket) do
    {:noreply,
     socket
     |> assign(:photo_data, nil)
     |> assign(:is_capturing, true)}
  end

  def handle_event("validate", %{"business_card" => business_card_params}, socket) do
    changeset =
      %BusinessCard{}
      |> BusinessCards.change_business_card(business_card_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"business_card" => business_card_params}, socket) do
    user = socket.assigns.current_user
    business_card_params = Map.put(business_card_params, "user_id", user.id)

    case BusinessCards.create_business_card(business_card_params) do
      {:ok, _business_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business card created successfully")
         |> push_navigate(to: ~p"/business-cards")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl">
      <.header>
        Scan Business Card
        <:subtitle>Take a photo of the business card to extract information</:subtitle>
      </.header>

            <%= if @is_capturing do %>
        <!-- Camera Capture Interface -->
        <div id="camera-capture" class="bg-white rounded-lg border border-zinc-200 p-6" phx-hook="CameraCapture">
          <div class="text-center">
            <div class="mx-auto h-64 w-full bg-zinc-100 rounded-lg flex items-center justify-center mb-4">
              <div class="text-center">
                <div class="mx-auto h-16 w-16 text-zinc-400 mb-4">
                  <.icon name="hero-camera" class="h-16 w-16" />
                </div>
                <p class="text-zinc-600">Camera access requested...</p>
              </div>
            </div>

            <div class="space-y-4">
              <button
                type="button"
                phx-click="photo-captured"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
              >
                <.icon name="hero-camera" class="h-4 w-4 mr-2" />
                Capture Photo
              </button>

              <button
                type="button"
                phx-click="retake-photo"
                class="inline-flex items-center px-4 py-2 border border-zinc-300 text-sm font-medium rounded-md text-zinc-700 bg-white hover:bg-zinc-50"
              >
                <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" />
                Back
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <%= if @photo_data do %>
          <!-- Photo Preview and Form -->
          <div class="bg-white rounded-lg border border-zinc-200 p-6">
            <div class="text-center mb-6">
              <img src={@photo_data} alt="Captured business card" class="mx-auto max-w-xs rounded-lg shadow-sm" />
              <div class="mt-4">
                <button
                  type="button"
                  phx-click="retake-photo"
                  class="text-sm text-zinc-600 hover:text-zinc-900"
                >
                  Retake Photo
                </button>
              </div>
            </div>

            <.simple_form
              for={@form}
              phx-change="validate"
              phx-submit="save"
              class="space-y-6"
            >
              <.input field={@form[:name]} type="text" label="Name" required />
              <.input field={@form[:email]} type="email" label="Email" />
              <.input field={@form[:phone]} type="tel" label="Phone" />
              <.input field={@form[:company]} type="text" label="Company" />
              <.input field={@form[:position]} type="text" label="Position" />

              <:actions>
                <.button phx-disable-with="Saving...">Save Business Card</.button>
                <.link navigate={~p"/business-cards"} class="button">
                  Cancel
                </.link>
              </:actions>
            </.simple_form>
          </div>
        <% else %>
          <!-- Start Camera Button -->
          <div class="bg-white rounded-lg border border-zinc-200 p-8 text-center">
            <div class="mx-auto h-16 w-16 text-zinc-400 mb-4">
              <.icon name="hero-camera" class="h-16 w-16" />
            </div>
            <h3 class="text-lg font-medium text-zinc-900 mb-2">Ready to scan?</h3>
            <p class="text-zinc-600 mb-6">
              Click the button below to open your camera and capture the business card.
            </p>
            <button
              phx-click="start-camera"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
            >
              <.icon name="hero-camera" class="h-4 w-4 mr-2" />
              Start Camera
            </button>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
