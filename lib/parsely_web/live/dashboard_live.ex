defmodule ParselyWeb.DashboardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard
  alias Parsely.OCRService
  alias Parsely.ImageService

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:ok,
     assign(socket,
       business_cards: business_cards,
       page_title: "Dashboard",
       show_camera: false,
       photo_data: nil,
       form: to_form(BusinessCards.change_business_card(%BusinessCard{}))
     )}
  end

  def handle_event("add-manually", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manual-entry")}
  end

  def handle_event("scan-card", _params, socket) do
    IO.puts("Scan card event received in LiveView")
    {:noreply,
     socket
     |> assign(show_camera: true)
     |> push_event("scan-card", %{})}
  end

    def handle_event("photo-captured", %{"data" => photo_data}, socket) do
    IO.puts("photo-captured event: starting image save + OCR")

    # Immediately switch UI to form/preview while processing
    socket =
      socket
      |> assign(:photo_data, photo_data)
      |> assign(:show_camera, false)

    IO.puts("UI state: show_camera=#{socket.assigns.show_camera}, photo_data=#{if socket.assigns.photo_data, do: "present", else: "nil"}")

    # Send immediate UI update to show photo preview
    # Then process OCR asynchronously
    Process.send_after(self(), {:process_ocr, photo_data}, 100)

    {:noreply, socket}
  end

  def handle_info({:process_ocr, photo_data}, socket) do
    # Process OCR asynchronously
    case ImageService.upload_image(photo_data, "business_card.jpg") do
      {:ok, image_url} ->
        # Then process the image with OCR
        {:ok, ocr_results} = OCRService.extract_business_card_info(photo_data)

        # Add the image URL to the OCR results
        ocr_results = Map.put(ocr_results, :image_url, image_url)

        changeset =
          %BusinessCard{}
          |> BusinessCards.change_business_card(ocr_results)

        IO.puts("Form populated with OCR results: #{inspect(changeset.changes)}")

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save image: #{reason}")}
    end
  end

  def handle_event("retake-photo", _params, socket) do
    {:noreply,
     socket
     |> assign(:photo_data, nil)
     |> assign(:show_camera, true)}
  end

  def handle_event("validate", %{"business_card" => business_card_params}, socket) do
    changeset =
      %BusinessCard{}
      |> BusinessCards.change_business_card(business_card_params)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"business_card" => business_card_params}, socket) do
    user = socket.assigns.current_user
    business_card_params = Map.put(business_card_params, "user_id", user.id)

    case BusinessCards.create_business_card(business_card_params) do
      {:ok, _business_card} ->
        business_cards = BusinessCards.list_business_cards(user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Business card created successfully")
         |> assign(business_cards: business_cards, photo_data: nil, show_camera: false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end



  def render(assigns) do
    ~H"""
    <div id="dashboard" class="mx-auto max-w-7xl" phx-hook="CameraCapture">

      <%= if @show_camera do %>
        <!-- Camera Capture Interface -->
        <div class="bg-white rounded-lg border border-zinc-200 p-6 mb-8">
          <div class="text-center">
            <div class="mx-auto h-64 w-full bg-zinc-100 rounded-lg flex items-center justify-center mb-4">
              <div class="text-center">
                <div class="mx-auto h-16 w-16 text-zinc-400 mb-4">
                  <.icon name="hero-camera" class="h-16 w-16" />
                </div>
                <p class="text-zinc-600">Camera access requested...</p>
              </div>
            </div>

            <div class="space-y-4 relative z-10">
              <button
                type="button"
                id="capture-photo-btn"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 relative z-10"
              >
                <.icon name="hero-camera" class="h-4 w-4 mr-2" />
                Capture Photo
              </button>

              <button
                type="button"
                phx-click="retake-photo"
                class="inline-flex items-center px-4 py-2 border border-zinc-300 text-sm font-medium rounded-md text-zinc-700 bg-white hover:bg-zinc-50 relative z-10"
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
          <div class="bg-white rounded-lg border border-zinc-200 p-6 mb-8">
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
                <button
                  type="button"
                  phx-click="retake-photo"
                  class="button button-outline"
                >
                  Retake Photo
                </button>
              </:actions>
            </.simple_form>
          </div>
        <% else %>
          <!-- Quick Actions Section -->
          <div class="mb-8">
            <div class="flex space-x-4">
              <!-- Scan Business Card -->
              <button
                phx-click="scan-card"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-camera" class="h-4 w-4 mr-2" />
                Scan Business Card
              </button>

              <!-- Add Manually -->
              <button
                phx-click="add-manually"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                <.icon name="hero-pencil-square" class="h-4 w-4 mr-2" />
                Add Manually
              </button>
            </div>
          </div>
        <% end %>
      <% end %>




    </div>
    """
  end
end
