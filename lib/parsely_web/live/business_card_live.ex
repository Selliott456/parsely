defmodule ParselyWeb.BusinessCardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:ok,
     assign(socket,
       business_cards: business_cards,
       page_title: "Business Cards",
       show_form: false,
       show_details: false,
       search_query: "",
       show_delete_modal: false,
       card_to_delete: nil
     )}
  end

      def handle_params(%{"id" => id}, _url, socket) do
    user = socket.assigns.current_user
    business_card = BusinessCards.get_business_card!(id, user.id)

    {:noreply,
     assign(socket,
       business_card: business_card,
       page_title: "Business Card Details",
       show_details: true
     )}
  end

  def handle_params(%{"action" => "new"} = params, _url, socket) do
    method = Map.get(params, "method", "camera")

    {:noreply,
     socket
     |> assign(:page_title, "New Business Card")
     |> assign(:business_card, nil)
     |> assign(:show_form, true)
     |> assign(:show_details, false)
     |> assign(:method, method)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("save", %{"business_card" => business_card_params}, socket) do
    user = socket.assigns.current_user
    business_card_params = Map.put(business_card_params, "user_id", user.id)

    case BusinessCards.create_business_card(business_card_params) do
      {:ok, business_card} ->
        business_cards = BusinessCards.list_business_cards(user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Business card created successfully")
         |> assign(business_cards: business_cards)
         |> push_navigate(to: ~p"/business-cards/#{business_card}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end



  def handle_event("show-delete-modal", %{"id" => id, "name" => name}, socket) do
    card_to_delete = %{id: id, name: name}
    {:noreply, assign(socket, show_delete_modal: true, card_to_delete: card_to_delete)}
  end

  def handle_event("confirm-delete", _params, socket) do
    user = socket.assigns.current_user
    card_id = socket.assigns.card_to_delete.id
    business_card = BusinessCards.get_business_card!(card_id, user.id)
    {:ok, _} = BusinessCards.delete_business_card(business_card)

    business_cards = BusinessCards.list_business_cards(user.id)

    {:noreply,
     socket
     |> put_flash(:info, "Business card deleted successfully")
     |> assign(business_cards: business_cards, show_delete_modal: false, card_to_delete: nil)}
  end

  def handle_event("cancel-delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false, card_to_delete: nil)}
  end

  def handle_event("add-note", %{"note" => note_params}, socket) do
    business_card = socket.assigns.business_card

    # Create new note object
    new_note = %{
      "note" => note_params["text"],
      "date" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Add to existing notes array
    updated_notes = [new_note | (business_card.notes || [])]

    case BusinessCards.update_business_card(business_card, %{notes: updated_notes}) do
      {:ok, updated_business_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note added successfully")
         |> assign(business_card: updated_business_card)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add note")}
    end
  end

  def handle_event("delete-note", %{"note-id" => _note_id}, socket) do
    # This would need a get_note function in the context
    # For now, we'll just show a message
    {:noreply, put_flash(socket, :info, "Note deletion not implemented yet")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.search_business_cards(user.id, query)

    {:noreply,
     socket
     |> assign(:business_cards, business_cards)
     |> assign(:search_query, query)}
  end

  def handle_event("clear-search", _params, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:noreply,
     socket
     |> assign(:business_cards, business_cards)
     |> assign(:search_query, "")}
  end

    def render(assigns) do
    ~H"""
    <%= if @show_form do %>
      <.live_component
        module={ParselyWeb.BusinessCardFormComponent}
        id="business_card-form"
        title="New Business Card"
        action={:new}
        patch={~p"/business-cards"}
        current_user={@current_user}
        method={@method}
      />
    <% else %>
      <%= if @show_details and @business_card do %>
        <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8">
          <div class="mt-4">
            <.header>
              Business Card Details
              <:actions>
                <.button_link_secondary navigate={~p"/business-cards"} class="!bg-brand/10 !hover:bg-brand/20 !text-brand hover:!text-brand">
                  ← Back to Cards
                </.button_link_secondary>
              </:actions>
            </.header>
          </div>

          <div class="mt-8 bg-white shadow rounded-lg">
            <div class="px-6 py-8">
              <div class="flex items-center mb-6">
                <div class="h-16 w-16 rounded-full bg-zinc-300 flex items-center justify-center">
                  <span class="text-2xl font-medium text-zinc-700">
                    <%= String.first(@business_card.name || "?") %>
                  </span>
                </div>
                <div class="ml-6">
                  <h2 class="text-2xl font-bold text-zinc-900"><%= @business_card.name %></h2>
                  <p class="text-lg text-zinc-600"><%= @business_card.position %></p>
                  <p class="text-lg text-zinc-600"><%= @business_card.company %></p>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%= if @business_card.email do %>
                  <div>
                    <h3 class="text-sm font-medium text-zinc-500">Email</h3>
                    <p class="mt-1 text-lg text-zinc-900"><%= @business_card.email %></p>
                  </div>
                <% end %>

                <%= if @business_card.phone do %>
                  <div>
                    <h3 class="text-sm font-medium text-zinc-500">Phone</h3>
                    <p class="mt-1 text-lg text-zinc-900"><%= @business_card.phone %></p>
                  </div>
                <% end %>
              </div>

              <!-- Notes Section -->
              <div class="mt-8">
                <h3 class="text-lg font-medium text-zinc-900 mb-4">Notes</h3>

                <%= if @business_card.notes && length(@business_card.notes) > 0 do %>
                  <div class="space-y-4">
                    <%= for note <- @business_card.notes do %>
                      <div class="bg-zinc-50 rounded-lg p-4">
                        <p class="text-zinc-900"><%= note["note"] %></p>
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
                <% else %>
                  <p class="text-zinc-500">No notes yet.</p>
                <% end %>

                <!-- Add Note Form -->
                <div class="mt-6">
                  <.simple_form for={%{}} phx-submit="add-note" class="space-y-4">
                    <.input
                      name="note[text]"
                      type="textarea"
                      value=""
                      label="Add Note"
                      placeholder="Enter a note about this contact..."
                      rows="3"
                    />
                    <:actions>
                      <.button_primary>Add Note</.button_primary>
                    </:actions>
                  </.simple_form>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mx-auto my-4 max-w-7xl px-4 sm:px-6 lg:px-8">
          <.header>
            <:actions>
              <.button_link patch={~p"/scan-card"} class="hover:text-white">
                <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                </svg>
                Add Card
              </.button_link>
            </:actions>
          </.header>

          <!-- Search Bar -->
          <div class="mt-6">
            <div class="w-full">
              <div class="flex items-center space-x-4">
                <div class="flex-1">
                  <form phx-change="search" class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                    </div>
                    <input
                      type="text"
                      name="query"
                      value={@search_query}
                      placeholder="Search business cards..."
                      class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                    />
                  </form>
                </div>
                <%= if @search_query != "" do %>
                  <.button_secondary
                    phx-click="clear-search"
                    class="inline-flex items-center"
                  >
                    <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    Clear
                  </.button_secondary>
                <% end %>
              </div>
            </div>
          </div>

          <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 items-stretch">
            <%= for business_card <- @business_cards do %>
              <div class="relative">
                <.link navigate={~p"/business-cards/#{business_card.id}"} class="block h-full">
                  <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition-shadow duration-200 cursor-pointer h-full flex flex-col min-h-[12rem]">
                  <div class="p-6 flex-1 flex flex-col">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                                              <img src={~p"/images/business-card.png"} alt="Business Card" class="h-10 w-10 object-cover" />
                      </div>
                      <div class="ml-4 flex-1 min-w-0">
                                              <h3 class="text-lg font-semibold text-charcoal truncate uppercase">
                        <%= business_card.name %>
                      </h3>
                        <p class="text-sm text-zinc-500 truncate">
                          <%= business_card.company %>
                        </p>
                      </div>

                    </div>

                    <%= if business_card.email do %>
                      <div class="mt-4">
                        <p class="text-sm text-zinc-600">
                          <span class="font-medium">Email:</span> <%= business_card.email %>
                        </p>
                      </div>
                    <% end %>

                    <%= if business_card.phone do %>
                      <div class="mt-2">
                        <p class="text-sm text-zinc-600">
                          <span class="font-medium">Phone:</span> <%= business_card.phone %>
                        </p>
                      </div>
                    <% end %>

                  </div>
                </div>
                </.link>

                <!-- Delete button positioned absolutely outside the link -->
                <button
                  phx-click="show-delete-modal"
                  phx-value-id={business_card.id}
                  phx-value-name={business_card.name}
                  class="absolute bottom-2 right-2 bg-brand/10 hover:bg-brand/20 text-brand p-2 rounded-full shadow-sm hover:shadow-md transition-all duration-200 transform hover:scale-105 z-10"
                >
                  <svg class="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M9 3v1H4v2h1v13a2 2 0 002 2h10a2 2 0 002-2V6h1V4h-5V3H9zM7 6h10v13H7V6zm2 2v9h2V8H9zm4 0v9h2V8h-2z"/>
                  </svg>
                </button>
              </div>
            <% end %>
          </div>

          <%= if Enum.empty?(@business_cards) do %>
            <div class="text-center py-12">
              <div class="mx-auto h-12 w-12 text-zinc-400">
                <svg class="h-12 w-12" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M10 20h4V4h-4v16zm-6 0h4v-8H4v8zM18 9v11h4V9h-4z"/>
                </svg>
              </div>
              <h3 class="mt-2 text-sm font-medium text-zinc-900">No business cards</h3>
              <p class="mt-1 text-sm text-zinc-500">
                Get started by adding your first business card.
              </p>
              <div class="mt-6">
                <.button_link patch={~p"/scan-card"}>
                  <svg class="h-4 w-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                  </svg>
                  Add Card
                </.button_link>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    <% end %>

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
                Are you sure you want to delete "<%= @card_to_delete.name %>"? This action cannot be undone.
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
end
