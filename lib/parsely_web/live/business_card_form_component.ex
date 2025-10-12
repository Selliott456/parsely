defmodule ParselyWeb.BusinessCardFormComponent do
  use ParselyWeb, :live_component

  alias Parsely.BusinessCards

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Add a new business card to your collection</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="business_card-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-6"
      >
        <div class="space-y-4">
          <%= if @method == "camera" do %>
            <!-- Photo Capture Section -->
            <div class="border-2 border-dashed border-zinc-300 rounded-lg p-6">
              <div class="text-center">
                <div class="mx-auto h-12 w-12 text-zinc-400">
                  <.icon name="hero-camera" class="h-12 w-12" />
                </div>
                <div class="mt-4">
                  <label for="photo-upload" class="cursor-pointer">
                    <span class="mt-2 block text-sm font-semibold text-zinc-900">
                      Take a photo of the business card
                    </span>
                    <span class="mt-1 block text-sm text-zinc-500">
                      Click to capture or drag and drop
                    </span>
                  </label>
                  <input
                    id="photo-upload"
                    type="file"
                    accept="image/*"
                    capture="environment"
                    phx-hook="PhotoCapture"
                    class="sr-only"
                  />
                </div>
              </div>

              <%= if @photo_data do %>
                <div class="mt-4">
                  <img src={@photo_data} alt="Captured business card" class="mx-auto max-w-xs rounded-lg shadow-sm" />
                  <div class="mt-2 text-center">
                    <.button_secondary
                      type="button"
                      phx-click="retake-photo"
                      phx-target={@myself}
                      class="text-sm"
                    >
                      Retake Photo
                    </.button_secondary>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- OCR Results Section -->
          <%= if @ocr_results do %>
            <div class="bg-green-50 border border-green-200 rounded-lg p-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <.icon name="hero-check-circle" class="h-5 w-5 text-green-400" />
                </div>
                <div class="ml-3">
                  <h3 class="text-sm font-medium text-green-800">
                    OCR Results Found
                  </h3>
                  <div class="mt-2 text-sm text-green-700">
                    <p>We found the following information from the business card:</p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Form Fields -->
          <.input field={@form[:name]} type="text" label="Name" required />
          <.input field={@form[:email]} type="email" label="Email" />
          <.input field={@form[:primary_phone]} type="tel" label="Primary Phone" />
          <.input field={@form[:secondary_phone]} type="tel" label="Secondary Phone" />
          <.input field={@form[:company]} type="text" label="Company" />
          <.input field={@form[:position]} type="text" label="Position" />
          <.input field={@form[:address]} type="textarea" label="Address" placeholder="Enter the business address..." rows="2" />
          <.input field={@form[:notes_text]} type="textarea" label="Notes" placeholder="Add any notes about this contact..." rows="3" />
        </div>

        <:actions>
          <.button_primary phx-disable-with="Saving...">Save Business Card</.button_primary>
          <.button_link_secondary patch={~p"/business-cards"}>
            Cancel
          </.button_link_secondary>
        </:actions>
      </.simple_form>
    </div>
    """
  end


  @impl true
  def update(%{id: _id} = assigns, socket) do
    changeset = BusinessCards.change_business_card(%BusinessCards.BusinessCard{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign(:photo_data, nil)
     |> assign(:ocr_results, nil)}
  end

  @impl true
  def handle_event("validate", %{"business_card" => business_card_params}, socket) do
    changeset =
      %BusinessCards.BusinessCard{}
      |> BusinessCards.change_business_card(business_card_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"business_card" => business_card_params}, socket) do
    save_business_card(socket, :new, business_card_params)
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
     |> assign(:ocr_results, ocr_results)
     |> assign_form(changeset)}
  end

  def handle_event("retake-photo", _params, socket) do
    {:noreply,
     socket
     |> assign(:photo_data, nil)
     |> assign(:ocr_results, nil)}
  end


  defp save_business_card(socket, :new, business_card_params) do
    user = socket.assigns.current_user
    business_card_params = Map.put(business_card_params, "user_id", user.id)

    # Check for duplicates before creating
    email = Map.get(business_card_params, "email")
    if email && BusinessCards.duplicate_exists?(user.id, email) do
      {:noreply,
       socket
       |> put_flash(:error, "A business card with this email already exists")
       |> assign_form(BusinessCards.change_business_card(business_card_params))}
    else
      case BusinessCards.create_business_card(business_card_params) do
        {:ok, business_card} ->
          notify_parent({:saved, business_card})

          {:noreply,
           socket
           |> put_flash(:info, "Business card created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign_form(socket, changeset)}
      end
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
