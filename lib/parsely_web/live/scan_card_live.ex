defmodule ParselyWeb.ScanCardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard
  alias Parsely.OCRService
  alias Parsely.ImageService

  def mount(_params, _session, socket) do
    socket = assign(socket,
      page_title: "Scan Business Card",
      show_camera: true,
      photo_data: nil,
      duplicate_error: nil,
      form: to_form(BusinessCards.change_business_card(%BusinessCard{}))
    )

    {:ok, socket}
  end

  def handle_event("photo-captured", %{"data" => photo_data}, socket) do
    IO.puts("photo-captured event: starting image save + OCR")

    # Hide camera and add photo data for form
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
    IO.puts("=== PROCESSING OCR ===")
    IO.puts("Current socket assigns: #{inspect(socket.assigns)}")

    # Process OCR asynchronously
    case ImageService.upload_image(photo_data, "business_card.jpg") do
      {:ok, image_url} ->
        IO.puts("Image saved successfully: #{image_url}")

        # Then process the image with OCR
        {:ok, ocr_results} = OCRService.extract_business_card_info(photo_data)
        IO.puts("OCR results: #{inspect(ocr_results)}")

        # Add the image URL to the OCR results
        ocr_results = Map.put(ocr_results, :image_url, image_url)

        # Always populate form with OCR results
        changeset =
          %BusinessCard{}
          |> BusinessCards.change_business_card(ocr_results)
          |> Map.put(:action, :validate)

        IO.puts("Form populated with OCR results: #{inspect(changeset.changes)}")
        IO.puts("Form data: #{inspect(changeset.data)}")

        updated_socket = assign(socket, :form, to_form(changeset))
        IO.puts("Updated socket assigns: #{inspect(updated_socket.assigns)}")
        IO.puts("Form field values: name=#{updated_socket.assigns.form[:name].value}, email=#{updated_socket.assigns.form[:email].value}")
        IO.puts("Form field values: phone=#{updated_socket.assigns.form[:phone].value}, company=#{updated_socket.assigns.form[:company].value}, position=#{updated_socket.assigns.form[:position].value}")

        {:noreply, updated_socket}

      {:error, reason} ->
        IO.puts("Failed to save image: #{reason}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save image: #{reason}")}
    end
  end

  def handle_event("retake-photo", _params, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/scan-card", replace: true)}
  end

  def handle_event("clear-duplicate-error", _params, socket) do
    {:noreply, assign(socket, :duplicate_error, nil)}
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

    # Check for duplicates before creating
    email = Map.get(business_card_params, "email")
    phone = Map.get(business_card_params, "phone")

    if BusinessCards.duplicate_exists?(user.id, email, phone) do
      # Duplicate found - show error and don't save
      {:noreply,
       socket
       |> assign(:duplicate_error, email)
       |> put_flash(:error, "A business card with this email already exists")}
    else
      # Handle notes field - if notes are provided, format them into JSON structure
      business_card_params = case Map.get(business_card_params, "notes") do
        notes when is_binary(notes) and byte_size(notes) > 0 ->
          # Format notes as JSON array with timestamp
          formatted_notes = [%{
            "note" => notes,
            "date" => DateTime.utc_now() |> DateTime.to_iso8601()
          }]
          Map.put(business_card_params, "notes", formatted_notes)
        _ ->
          # No notes provided, set empty array
          Map.put(business_card_params, "notes", [])
      end

      case BusinessCards.create_business_card(business_card_params) do
        {:ok, _business_card} ->
          {:noreply,
           socket
           |> put_flash(:info, "Business card created successfully")
           |> push_navigate(to: ~p"/dashboard")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  def render(assigns) do
    IO.puts("=== RENDERING SCAN CARD ===")
    IO.puts("show_camera: #{assigns.show_camera}")
    IO.puts("photo_data: #{if assigns.photo_data, do: "present", else: "nil"}")
    IO.puts("form: #{if assigns.form, do: "present", else: "nil"}")

    ~H"""
    <div id="scan-card" class="mx-auto max-w-4xl" phx-hook="CameraCapture">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Scan Business Card</h1>
        <p class="text-gray-600">Take a photo of a business card to extract information</p>
      </div>

      <%= if @show_camera do %>
        <!-- Camera Capture Interface -->
        <div class="bg-white rounded-lg border border-zinc-200 p-6 mb-8">
          <div class="text-center">
            <div class="mx-auto h-64 w-full bg-zinc-100 rounded-lg flex items-center justify-center mb-4">
              <div class="text-center">
                <div class="mx-auto h-16 w-16 text-zinc-400 mb-4">
                  <.icon name="hero-camera" class="h-16 w-16" />
                </div>
                <p class="text-zinc-600" id="camera-status">Initializing camera...</p>
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
      <% end %>

      <%= if @photo_data do %>
        <!-- Photo Preview Area -->
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
        </div>
      <% end %>



      <!-- Form - Always Visible -->
      <div class="bg-white rounded-lg border border-zinc-200 p-6 mb-8">
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
          <.input field={@form[:notes]} type="textarea" label="Notes" placeholder="Add any notes about this contact..." rows="3" />

          <:actions>
            <button
              type="submit"
              class={"px-4 py-2 text-sm font-medium rounded-md #{if @duplicate_error, do: "bg-gray-300 text-gray-500 cursor-not-allowed", else: "bg-blue-600 text-white hover:bg-blue-700"}"}
              disabled={@duplicate_error != nil}
            >
              Save Business Card
            </button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
