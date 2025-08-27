defmodule ParselyWeb.BusinessCardDetailLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    case BusinessCards.get_business_card!(id, user.id) do
      business_card ->
        {:ok,
         assign(socket,
           business_card: business_card,
           page_title: "#{business_card.name || "Business Card"} - Details"
         )}
    end
  rescue
    Ecto.NoResultsError ->
      {:ok, push_navigate(socket, to: ~p"/business-cards")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <div class="mb-6">
        <.button_link_secondary navigate={~p"/business-cards"} class="mb-4">
          ← Back to Cards
        </.button_link_secondary>

        <h1 class="text-3xl font-bold text-charcoal">
          <%= @business_card.name || "Unnamed Contact" %>
        </h1>
      </div>

      <div class="bg-white rounded-lg border border-zinc-200 p-8">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- Contact Information -->
          <div>
            <h2 class="text-xl font-semibold text-charcoal mb-4">Contact Information</h2>
            <div class="space-y-4">
              <%= if @business_card.email do %>
                <div>
                  <label class="block text-sm font-medium text-zinc-600">Email</label>
                  <p class="mt-1 text-lg text-charcoal">
                    <a href={"mailto:#{@business_card.email}"} class="text-mint-deep hover:text-mint-primary transition-colors">
                      <%= @business_card.email %>
                    </a>
                  </p>
                </div>
              <% end %>

              <%= if @business_card.phone do %>
                <div>
                  <label class="block text-sm font-medium text-zinc-600">Phone</label>
                  <p class="mt-1 text-lg text-charcoal">
                    <a href={"tel:#{@business_card.phone}"} class="text-mint-deep hover:text-mint-primary transition-colors">
                      <%= @business_card.phone %>
                    </a>
                  </p>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Professional Information -->
          <div>
            <h2 class="text-xl font-semibold text-charcoal mb-4">Professional Information</h2>
            <div class="space-y-4">
              <%= if @business_card.company do %>
                <div>
                  <label class="block text-sm font-medium text-zinc-600">Company</label>
                  <p class="mt-1 text-lg text-charcoal"><%= @business_card.company %></p>
                </div>
              <% end %>

              <%= if @business_card.position do %>
                <div>
                  <label class="block text-sm font-medium text-zinc-600">Position</label>
                  <p class="mt-1 text-lg text-charcoal"><%= @business_card.position %></p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Notes -->
        <%= if @business_card.notes && @business_card.notes != "" do %>
          <div class="mt-8 pt-8 border-t border-zinc-200">
            <h2 class="text-xl font-semibold text-charcoal mb-4">Notes</h2>
            <div class="bg-zinc-50 rounded-lg p-4">
              <p class="text-charcoal whitespace-pre-wrap"><%= @business_card.notes %></p>
            </div>
          </div>
        <% end %>

        <!-- Card Metadata -->
        <div class="mt-8 pt-8 border-t border-zinc-200">
          <div class="flex items-center justify-between text-sm text-zinc-500">
            <div>
              <span>Added: <%= Calendar.strftime(@business_card.inserted_at, "%B %d, %Y") %></span>
              <%= if @business_card.updated_at != @business_card.inserted_at do %>
                <span class="ml-4">Updated: <%= Calendar.strftime(@business_card.updated_at, "%B %d, %Y") %></span>
              <% end %>
            </div>
            <div class="flex space-x-2">
              <.button_secondary phx-click="edit_card" class="text-sm">
                Edit
              </.button_secondary>
              <.button_secondary phx-click="delete_card" class="text-sm bg-red-50 text-red-600 hover:bg-red-100">
                Delete
              </.button_secondary>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("edit_card", _params, socket) do
    {:navigate, socket, to: ~p"/business-cards/#{socket.assigns.business_card.id}/edit"}
  end

  def handle_event("delete_card", _params, socket) do
    business_card = socket.assigns.business_card

    case BusinessCards.delete_business_card(business_card) do
      {:ok, _} ->
        {:navigate, socket, to: ~p"/business-cards", flash: %{info: "Business card deleted successfully."}}

      {:error, _} ->
        {:navigate, socket, to: ~p"/business-cards", flash: %{error: "Failed to delete business card."}}
    end
  end
end
