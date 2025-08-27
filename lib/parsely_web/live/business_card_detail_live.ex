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
        <div class="mt-8 pt-8 border-t border-zinc-200">
          <h2 class="text-xl font-semibold text-charcoal mb-4">Notes</h2>

          <%= if @business_card.notes && length(@business_card.notes) > 0 do %>
            <div class="space-y-4 mb-6">
              <%= for note <- @business_card.notes do %>
                <div class="bg-zinc-50 rounded-lg p-4">
                  <p class="text-charcoal whitespace-pre-wrap"><%= note["note"] %></p>
                  <p class="text-sm text-zinc-500 mt-2">
                    <%= case DateTime.from_iso8601(note["date"]) do %>
                      <% {:ok, datetime, _} -> %>
                        <%= Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p") %>
                      <% _ -> %>
                        <%= note["date"] %>
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Add Note Form -->
          <div class="bg-white border border-zinc-200 rounded-lg p-4">
            <form phx-submit="add-note" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-zinc-600 mb-2">Add Note</label>
                <textarea
                  name="note[text]"
                  placeholder="Enter a note about this contact..."
                  rows="3"
                  class="block w-full border border-zinc-300 rounded-md px-3 py-2 text-zinc-900 placeholder-zinc-500 focus:outline-none focus:ring-1 focus:ring-mint-primary focus:border-mint-primary"
                  required
                ></textarea>
              </div>
              <div class="flex justify-end">
                <.button_primary type="submit">Add Note</.button_primary>
              </div>
            </form>
          </div>
        </div>

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

  def handle_event("add-note", %{"note" => %{"text" => note_text}}, socket) do
    business_card = socket.assigns.business_card

    # Create new note with current timestamp
    new_note = %{
      "note" => note_text,
      "date" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Add note to existing notes or create new notes array
    updated_notes = case business_card.notes do
      nil -> [new_note]
      notes when is_list(notes) -> [new_note | notes]
      _ -> [new_note]
    end

    # Update the business card
    case BusinessCards.update_business_card(business_card, %{notes: updated_notes}) do
      {:ok, updated_card} ->
        {:noreply, assign(socket, business_card: updated_card)}

      {:error, _} ->
        {:noreply, socket}
    end
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
