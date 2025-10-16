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
           page_title: "#{business_card.name || "Business Card"} - Details",
           show_delete_modal: false
         )}
    end
  rescue
    Ecto.NoResultsError ->
      {:ok, push_navigate(socket, to: ~p"/business-cards")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl my-8">
      <div class="mb-6">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl md:text-3xl font-bold text-charcoal">
            <%= @business_card.name || "Unnamed Contact" %>
          </h1>

          <.button_link_secondary navigate={~p"/business-cards"} class="w-32 sm:w-44 md:w-auto text-center justify-center !bg-brand/10 !hover:bg-brand/20 !text-brand hover:!text-brand">
            ← Cards
          </.button_link_secondary>
        </div>
      </div>

      <div class="">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 bg-brand/10 rounded-lg p-4">
          <!-- Contact Information -->
          <div class="border-b border-zinc-200 pt-6 pb-12 md:pt-0 md:pb-0 md:border-b-0 md:pr-20 md:border-r md:border-zinc-200">
            <h2 class="text-lg md:text-xl font-semibold text-charcoal mb-4">Contact Information</h2>
            <div class="space-y-4">
              <%= if @business_card.email do %>
                <div>
                  <p class="text-base md:text-lg text-charcoal break-words">
                    <a href={"mailto:#{@business_card.email}"} class="text-mint-deep hover:text-mint-primary transition-colors">
                      <%= @business_card.email %>
                    </a>
                  </p>
                </div>
              <% end %>

              <%= if @business_card.primary_phone do %>
                <div>
                  <p class="text-base md:text-lg text-charcoal break-words">
                    <a href={"tel:#{@business_card.primary_phone}"} class="text-mint-deep hover:text-mint-primary transition-colors">
                      <%= @business_card.primary_phone %>
                    </a>
                  </p>
                </div>
              <% end %>

              <%= if @business_card.secondary_phone do %>
                <div>
                  <p class="text-base md:text-lg text-charcoal break-words">
                    <a href={"tel:#{@business_card.secondary_phone}"} class="text-mint-deep hover:text-mint-primary transition-colors">
                      <%= @business_card.secondary_phone %>
                    </a>
                  </p>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Professional Information -->
          <div class="pt-4 md:pt-0 md:pl-8">
            <h2 class="text-lg md:text-xl font-semibold text-charcoal mb-4">Professional Information</h2>
            <div class="space-y-4">
              <%= if @business_card.company do %>
                <div>
                  <p class="mt-1 text-base md:text-lg text-charcoal"><%= @business_card.company %></p>
                </div>
              <% end %>

              <%= if @business_card.position do %>
                <div>
                  <p class="mt-1 text-base md:text-lg text-charcoal"><%= @business_card.position %></p>
                </div>
              <% end %>

              <%= if @business_card.address do %>
                <div class="pt-4 md:border-t border-zinc-200">
                  <p class="text-base md:text-lg text-charcoal"><%= @business_card.address %></p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Notes -->
        <div class="mt-8 pt-8">

          <%= if @business_card.notes && length(@business_card.notes) > 0 do %>
            <h2 class="text-lg md:text-xl font-semibold text-charcoal mb-4 md:hidden">NOTES</h2>

            <div class="space-y-4 mb-6">

              <%= for {note, index} <- Enum.with_index(@business_card.notes) do %>
                <div class="bg-zinc-50 rounded-lg p-4">
                  <div class="flex justify-between items-start">
                    <div class="flex-1">
                      <p class="text-charcoal whitespace-pre-wrap"><%= note["note"] %></p>
                      <p class="text-sm text-mint-primary mt-2">
                        <%= case DateTime.from_iso8601(note["date"]) do %>
                          <% {:ok, datetime, _} -> %>
                            <%= Calendar.strftime(datetime, "%B %d, %Y") %>
                          <% _ -> %>
                            <%= note["date"] %>
                        <% end %>
                      </p>
                    </div>
                    <button
                      phx-click="delete-note"
                      phx-value-index={index}
                      class="bg-brand/10 hover:bg-brand/20 text-brand p-2 rounded-full shadow-sm hover:shadow-md transition-all duration-200 transform hover:scale-105 ml-4 flex-shrink-0"
                    >
                      <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M9 3v1H4v2h1v13a2 2 0 002 2h10a2 2 0 002-2V6h1V4h-5V3H9zM7 6h10v13H7V6zm2 2v9h2V8H9zm4 0v9h2V8h-2z"/>
                      </svg>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Add Note Form -->
          <div>
            <form phx-submit="add-note" class="space-y-4">
              <div>
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
              <.button_secondary phx-click="show-delete-modal" class="text-sm bg-red-50 text-red-600 hover:bg-red-100">
                Delete
              </.button_secondary>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal -->
    <%= if @show_delete_modal do %>
      <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" id="delete-modal">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
          <div class="mt-3 text-center">
            <div class="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100">
              <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 19.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mt-4">Delete Business Card</h3>
            <div class="mt-2 px-7 py-3">
              <p class="text-sm text-gray-500">
                Are you sure you want to delete "<%= @business_card.name %>"? This action cannot be undone.
              </p>
            </div>
            <div class="items-center px-4 py-3">
              <button
                phx-click="confirm-delete"
                class="px-4 py-2 bg-red-600 text-white text-base font-medium rounded-md w-24 mr-2 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-300"
              >
                Delete
              </button>
              <button
                phx-click="cancel-delete"
                class="px-4 py-2 bg-gray-300 text-gray-800 text-base font-medium rounded-md w-24 hover:bg-gray-400 focus:outline-none focus:ring-2 focus:ring-gray-300"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
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

  def handle_event("delete-note", %{"index" => index}, socket) do
    business_card = socket.assigns.business_card
    index = String.to_integer(index)

    # Remove the note at the specified index
    updated_notes = case business_card.notes do
      nil -> []
      notes when is_list(notes) -> List.delete_at(notes, index)
      _ -> []
    end

    # Update the business card
    case BusinessCards.update_business_card(business_card, %{notes: updated_notes}) do
      {:ok, updated_card} ->
        {:noreply, assign(socket, business_card: updated_card)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("show-delete-modal", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: true)}
  end

  def handle_event("confirm-delete", _params, socket) do
    business_card = socket.assigns.business_card

    case BusinessCards.delete_business_card(business_card) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Business card deleted successfully.")
         |> push_navigate(to: ~p"/business-cards")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete business card.")
         |> push_navigate(to: ~p"/business-cards")}
    end
  end

  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false)}
  end
end
