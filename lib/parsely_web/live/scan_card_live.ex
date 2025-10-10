defmodule ParselyWeb.ScanCardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard
  alias Parsely.OCRService
  alias Parsely.ImageService

  def mount(_params, _session, socket) do
    # Default OCR language from current Gettext locale
    locale = Gettext.get_locale(ParselyWeb.Gettext)
    ocr_lang = if locale == "ja", do: "jpn", else: "eng"

    socket = assign(socket,
      page_title: "Scan Business Card",
      show_camera: true,
      photo_data: nil,
      duplicate_error: nil,
      processing_ocr: false,
      form: to_form(BusinessCards.change_business_card(%BusinessCard{})),
      ocr_language: ocr_lang,
      selected_lines: %{}
    )

    {:ok, socket}
  end



  def handle_info({:process_ocr, photo_data}, socket) do
    IO.puts("=== PROCESSING OCR ===")
    IO.puts("Current socket assigns: #{inspect(socket.assigns)}")

    # Process OCR asynchronously
    case ImageService.upload_image(photo_data, "business_card.jpg") do
      {:ok, image_url} ->
        IO.puts("Image saved successfully: #{image_url}")

        # Then process the image with OCR
        {:ok, ocr_results} = OCRService.extract_business_card_info(photo_data, socket.assigns.ocr_language)

        # Debug: Show ALL OCR data gathered from photo
        IO.puts("=" |> String.duplicate(80))
        IO.puts("🔍 COMPLETE OCR DATA FROM PHOTO:")
        IO.puts("=" |> String.duplicate(80))
        IO.inspect(ocr_results, label: "📄 Raw OCR Results", pretty: true, width: 120)
        IO.puts("=" |> String.duplicate(80))

        # Add the image URL to the OCR results
        ocr_results = Map.put(ocr_results, :image_url, image_url)

        # Store raw_text in ocr_data field since it's not a schema field
        ocr_data = %{raw_text: ocr_results.raw_text}
        ocr_results = Map.put(ocr_results, :ocr_data, ocr_data)

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

        {:noreply, assign(updated_socket, :processing_ocr, false)}

      {:error, reason} ->
        IO.puts("Failed to save image: #{reason}")
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save image: #{reason}")}
    end
  end

  def handle_event("photo-captured", %{"data" => photo_data}, socket) do
    IO.puts("photo-captured event: starting image save + OCR")

    # Hide camera, add photo data, and show loading state immediately
    socket =
      socket
      |> assign(:photo_data, photo_data)
      |> assign(:show_camera, false)
      |> assign(:processing_ocr, true)

    IO.puts("UI state: show_camera=#{socket.assigns.show_camera}, photo_data=#{if socket.assigns.photo_data, do: "present", else: "nil"}, processing_ocr=#{socket.assigns.processing_ocr}")

    # Process OCR immediately (not with delay)
    Process.send(self(), {:process_ocr, photo_data}, [])

    {:noreply, socket}
  end

  def handle_event("retake-photo", _params, socket) do
    {:noreply,
     socket
     |> push_navigate(to: ~p"/scan-card", replace: true)}
  end

  def handle_event("set-ocr-language", %{"lang" => lang}, socket) do
    # Accept only known values to avoid invalid API params
    lang = if lang in ["eng", "jpn", "eng,jpn"], do: lang, else: "eng"
    # Persist a matching site locale cookie (en/ja) without reload
    locale = if String.starts_with?(lang, "jpn"), do: "ja", else: "en"
    socket = Phoenix.LiveView.push_event(socket, "set-locale-cookie", %{locale: locale})
    {:noreply, assign(socket, :ocr_language, lang)}
  end

  def handle_event("clear-duplicate-error", _params, socket) do
    {:noreply, assign(socket, :duplicate_error, nil)}
  end

  def handle_event("email-changed", _params, socket) do
    # Clear duplicate error when email field changes
    {:noreply, assign(socket, :duplicate_error, nil)}
  end

  def handle_event("toggle-line", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_selected = socket.assigns.selected_lines

    # Toggle the selected state for this line
    new_selected = if Map.get(current_selected, index, false) do
      Map.delete(current_selected, index)
    else
      Map.put(current_selected, index, true)
    end

    {:noreply, assign(socket, :selected_lines, new_selected)}
  end

  def handle_event("validate", %{"business_card" => business_card_params}, socket) do
    changeset =
      %BusinessCard{}
      |> BusinessCards.change_business_card(business_card_params)

    # Clear duplicate error if email has changed from the duplicate email
    updated_socket = case {socket.assigns.duplicate_error, Map.get(business_card_params, "email")} do
      {duplicate_email, current_email} when duplicate_email == current_email ->
        # Email is still the same, keep duplicate error
        socket
      {duplicate_email, current_email} when is_binary(duplicate_email) and is_binary(current_email) ->
        # Email has changed, clear duplicate error
        assign(socket, :duplicate_error, nil)
      _ ->
        # No duplicate error or no email, keep as is
        socket
    end

    {:noreply, assign(updated_socket, form: to_form(changeset))}
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
    <div id="scan-card" class="mx-auto max-w-4xl pb-16 min-h-screen" phx-hook="CameraCapture">
      <div id="locale-hook" phx-hook="LocaleCookie"></div>

      <!-- OCR Language Selector -->
      <div class="bg-white rounded-lg border border-zinc-200 p-4 mt-6">
        <div class="flex items-center justify-between">
          <p class="text-sm text-zinc-700">OCR Language</p>
          <div class="inline-flex items-center gap-2">
            <button
              type="button"
              phx-click="set-ocr-language"
              phx-value-lang="eng"
              class={["px-3 py-1 rounded-md text-sm ring-1",
                @ocr_language == "eng" && "bg-mint-deep text-white ring-mint-deep",
                @ocr_language != "eng" && "bg-white text-zinc-700 ring-zinc-300 hover:bg-zinc-50"]}
            >English</button>
            <button
              type="button"
              phx-click="set-ocr-language"
              phx-value-lang="jpn"
              class={["px-3 py-1 rounded-md text-sm ring-1",
                @ocr_language == "jpn" && "bg-mint-deep text-white ring-mint-deep",
                @ocr_language != "jpn" && "bg-white text-zinc-700 ring-zinc-300 hover:bg-zinc-50"]}
            >日本語</button>
          </div>
        </div>
        <p class="mt-2 text-xs text-zinc-500">Current: <span class="font-medium"><%= @ocr_language %></span></p>
      </div>

      <%= if @show_camera do %>
        <!-- Camera Capture Interface -->
        <div class="bg-white rounded-lg border border-zinc-200 p-6 my-8">
          <div class="text-center">
            <div id="camera-container" phx-update="ignore" class="mx-auto h-64 w-full bg-zinc-100 rounded-lg flex items-center justify-center mb-4">
              <div class="text-center">
                <div class="mx-auto h-16 w-16 text-zinc-400 mb-4">
                  <svg class="h-16 w-16" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M12 15.2a3.2 3.2 0 100-6.4 3.2 3.2 0 000 6.4z"/>
                    <path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/>
                  </svg>
                </div>
                <p class="text-zinc-600" id="camera-status">Initializing camera...</p>
              </div>
            </div>

            <div class="space-y-4 relative z-10">
              <.button_primary
                type="button"
                id="capture-photo-btn"
                class="inline-flex items-center relative z-10"
              >
                <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 15.2a3.2 3.2 0 100-6.4 3.2 3.2 0 000 6.4z"/>
                  <path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/>
                </svg>
                Capture Photo
              </.button_primary>

            </div>
          </div>
        </div>
      <% end %>

      <%= if @photo_data do %>
        <!-- Photo Preview Area -->
        <div class="bg-white rounded-lg border border-zinc-200 p-6 mb-8">
          <div class="text-center mb-6">
            <%= if @processing_ocr do %>
              <div class="mx-auto max-w-xs">
                <img src={@photo_data} alt="Captured business card" class="mx-auto max-w-xs rounded-lg shadow-sm opacity-50" />
                <div class="mt-4 flex items-center justify-center">
                  <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span class="ml-2 text-sm text-gray-600">Processing image...</span>
                </div>
              </div>
            <% else %>
              <img src={@photo_data} alt="Captured business card" class="mx-auto max-w-xs rounded-lg shadow-sm" />
            <% end %>
            <div class="mt-4">
              <.button_secondary
                type="button"
                phx-click="retake-photo"
                class="text-sm"
              >
                Retake Photo
              </.button_secondary>
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
          class="space-y-6 pb-4"
        >
          <.input field={@form[:name]} type="text" label="Name" required />
          <.input field={@form[:email]} type="email" label="Email" phx-change="email-changed" />
          <.input field={@form[:phone]} type="tel" label="Phone" />
          <.input field={@form[:company]} type="text" label="Company" />
          <.input field={@form[:position]} type="text" label="Position" />
          <.input field={@form[:notes]} type="textarea" label="Notes" placeholder="Add any notes about this contact..." rows="3" />

          <!-- Raw OCR Text Display -->
          <%= if @form.source.changes[:ocr_data] && @form.source.changes[:ocr_data][:raw_text] do %>
            <div class="mt-6 p-4 bg-gray-50 rounded-lg border">
              <h3 class="text-sm font-medium text-gray-700 mb-2">Raw OCR Text:</h3>
              <div class="space-y-1 max-h-32 overflow-y-auto">
                <%= for {line, index} <- @form.source.changes[:ocr_data][:raw_text] |> String.split("\n") |> Enum.with_index() do %>
                  <%= if String.trim(line) != "" do %>
                    <button
                      type="button"
                      phx-click="toggle-line"
                      phx-value-index={index}
                      class={[
                        "w-full text-left px-3 py-2 rounded-md text-xs font-mono transition-colors",
                        if(Map.get(assigns, :selected_lines, %{})[index], do: "bg-mint-deep text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50")
                      ]}
                    >
                      <%= line %>
                    </button>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% end %>

          <:actions>
            <div class="pt-4 pb-8">
              <.button_primary
                type="submit"
                class={if @duplicate_error, do: "opacity-50 cursor-not-allowed"}
                disabled={@duplicate_error != nil}
              >
                Save Business Card
              </.button_primary>
            </div>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
