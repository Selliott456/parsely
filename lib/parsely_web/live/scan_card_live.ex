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
      selected_lines: %{},
      show_assign_modal: false,
      selected_ocr_line: nil,
      selected_ocr_text: nil,
      assigned_ocr_lines: MapSet.new(),
      assigned_fields: MapSet.new()
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
        IO.puts("Form field values: address=#{updated_socket.assigns.form[:address].value}")

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

    # Get the OCR text for this line
    ocr_text = if socket.assigns.form.source.changes[:ocr_data] && socket.assigns.form.source.changes[:ocr_data][:raw_text] do
      lines = String.split(socket.assigns.form.source.changes[:ocr_data][:raw_text], "\n")
      Enum.at(lines, index, "")
    else
      ""
    end

    # Open the assignment modal
    {:noreply, assign(socket,
      show_assign_modal: true,
      selected_ocr_line: index,
      selected_ocr_text: ocr_text
    )}
  end

  def handle_event("close-assign-modal", _params, socket) do
    {:noreply, assign(socket,
      show_assign_modal: false,
      selected_ocr_line: nil,
      selected_ocr_text: nil
    )}
  end

  def handle_event("assign-to-field", %{"field" => field_name}, socket) do
    # Get current form data
    current_changes = socket.assigns.form.source.changes
    selected_text = socket.assigns.selected_ocr_text
    selected_line_index = socket.assigns.selected_ocr_line

    # Handle notes field specially - append to existing notes
    updated_changes = if field_name == "notes" do
      current_notes = Map.get(current_changes, :notes_text, "")
      new_notes = if current_notes == "" do
        selected_text
      else
        current_notes <> "\n" <> selected_text
      end
      Map.put(current_changes, :notes_text, new_notes)
    else
      # Update the specified field with the selected OCR text
      Map.put(current_changes, String.to_atom(field_name), selected_text)
    end

    # Create new changeset with updated data
    changeset =
      %BusinessCards.BusinessCard{}
      |> BusinessCards.change_business_card(updated_changes)
      |> Map.put(:action, :validate)

    # Track assigned items - hide OCR pills for all fields including notes
    new_assigned_ocr_lines = MapSet.put(socket.assigns.assigned_ocr_lines, selected_line_index)

    # Only track field assignments for non-notes fields (notes field never disappears)
    new_assigned_fields = if field_name != "notes" do
      MapSet.put(socket.assigns.assigned_fields, field_name)
    else
      socket.assigns.assigned_fields
    end

    # Close modal and update form
    {:noreply, assign(socket,
      show_assign_modal: false,
      selected_ocr_line: nil,
      selected_ocr_text: nil,
      form: to_form(changeset),
      assigned_ocr_lines: new_assigned_ocr_lines,
      assigned_fields: new_assigned_fields
    )}
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
      # The notes_text virtual field will be automatically converted to notes array in the changeset

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
          <.input field={@form[:primary_phone]} type="tel" label="Primary Phone" />
          <.input field={@form[:secondary_phone]} type="tel" label="Secondary Phone" />
          <.input field={@form[:company]} type="text" label="Company" />
          <.input field={@form[:position]} type="text" label="Position" />
          <.input field={@form[:address]} type="textarea" label="Address" placeholder="Enter the business address..." rows="2" />
          <.input field={@form[:notes_text]} type="textarea" label="Notes" placeholder="Add any notes about this contact..." rows="3" />

          <!-- Raw OCR Text Display -->
          <%= if @form.source.changes[:ocr_data] && @form.source.changes[:ocr_data][:raw_text] do %>
            <div class="mt-6 p-4 bg-brand/10 rounded-lg border border-gray-300">
              <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-2">Add information manually:</label>
              <div class="flex flex-wrap gap-2 max-h-32 overflow-y-auto">
                <%= for {line, index} <- @form.source.changes[:ocr_data][:raw_text] |> String.split("\n") |> Enum.with_index() do %>
                  <%= if String.trim(line) != "" && !MapSet.member?(@assigned_ocr_lines, index) do %>
                    <button
                      type="button"
                      phx-click="toggle-line"
                      phx-value-index={index}
                      class="inline-block px-3 py-2 rounded-lg text-sm font-semibold bg-gray-100 text-gray-700 border border-gray-300 hover:bg-gray-200 transition-colors"
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
                class={"!bg-brand/10 !hover:bg-brand/20 !text-brand hover:!text-brand #{if @duplicate_error, do: "opacity-50 cursor-not-allowed", else: ""}"}
                disabled={@duplicate_error != nil}
              >
                Save Business Card
              </.button_primary>
            </div>
          </:actions>
        </.simple_form>
      </div>

      <!-- Assignment Modal -->
      <%= if @show_assign_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" phx-click="close-assign-modal">
          <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4" phx-click-away="close-assign-modal">
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-lg font-semibold text-gray-900">Assign OCR Text</h3>
              <button
                type="button"
                phx-click="close-assign-modal"
                class="text-gray-400 hover:text-gray-600"
              >
                <.icon name="hero-x-mark" class="h-6 w-6" />
              </button>
            </div>

            <div class="mb-4">
              <p class="text-sm text-gray-600 mb-2">Selected text:</p>
              <div class="bg-gray-100 p-3 rounded-md font-mono text-sm">
                "<%= @selected_ocr_text %>"
              </div>
            </div>

            <div class="space-y-2">
              <p class="text-sm font-medium text-gray-700">Assign to field:</p>
              <div class="grid grid-cols-1 gap-2">
                <%= unless MapSet.member?(@assigned_fields, "name") do %>
                  <button
                    type="button"
                    phx-click="assign-to-field"
                    phx-value-field="name"
                    class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                  >
                    <div class="font-medium text-gray-900">Name</div>
                    <div class="text-sm text-gray-500">Person's full name</div>
                  </button>
                <% end %>

                <%= unless MapSet.member?(@assigned_fields, "email") do %>
                  <button
                    type="button"
                    phx-click="assign-to-field"
                    phx-value-field="email"
                    class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                  >
                    <div class="font-medium text-gray-900">Email</div>
                    <div class="text-sm text-gray-500">Email address</div>
                  </button>
                <% end %>

                <%= unless MapSet.member?(@assigned_fields, "phone") do %>
                  <button
                    type="button"
                    phx-click="assign-to-field"
                    phx-value-field="phone"
                    class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                  >
                    <div class="font-medium text-gray-900">Phone</div>
                    <div class="text-sm text-gray-500">Phone number</div>
                  </button>
                <% end %>

                <%= unless MapSet.member?(@assigned_fields, "company") do %>
                  <button
                    type="button"
                    phx-click="assign-to-field"
                    phx-value-field="company"
                    class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                  >
                    <div class="font-medium text-gray-900">Company</div>
                    <div class="text-sm text-gray-500">Company or organization name</div>
                  </button>
                <% end %>

                <%= unless MapSet.member?(@assigned_fields, "position") do %>
                  <button
                    type="button"
                    phx-click="assign-to-field"
                    phx-value-field="position"
                    class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                  >
                    <div class="font-medium text-gray-900">Position</div>
                    <div class="text-sm text-gray-500">Job title or position</div>
                  </button>
                <% end %>

                <!-- Always show Add to Notes option -->
                <button
                  type="button"
                  phx-click="assign-to-field"
                  phx-value-field="notes"
                  class="w-full text-left px-4 py-3 bg-mint-primary/10 border border-gray-300 rounded-md hover:bg-mint-primary/20 transition-colors"
                >
                  <div class="font-medium text-gray-900">Add to Notes</div>
                  <div class="text-sm text-gray-500">Add this text to the notes field</div>
                </button>
              </div>
            </div>

            <div class="mt-6 flex justify-end">
              <button
                type="button"
                phx-click="close-assign-modal"
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
