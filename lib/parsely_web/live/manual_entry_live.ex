defmodule ParselyWeb.ManualEntryLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Add Business Card Manually",
       form: to_form(BusinessCards.change_business_card(%BusinessCard{}))
     )}
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

    # Check for duplicates before creating
    email = Map.get(business_card_params, "email")
    if email && BusinessCards.duplicate_exists?(user.id, email) do
      {:noreply,
       socket
       |> put_flash(:error, "A business card with this email already exists")
       |> assign(form: to_form(BusinessCards.change_business_card(business_card_params)))}
    else
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
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl">
      <.header>
        Add Business Card Manually
        <:subtitle>Enter the contact information manually</:subtitle>
      </.header>

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
    """
  end
end
