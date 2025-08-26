defmodule ParselyWeb.BusinessCardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:ok,
     assign(socket,
       business_cards: business_cards,
       page_title: "Business Cards",
       show_form: false,
       show_details: false,
       search_query: ""
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

  def handle_event("save-virtual", %{"business_card" => business_card_params}, socket) do
    user = socket.assigns.current_user
    business_card_params = Map.put(business_card_params, "user_id", user.id)

    case BusinessCards.create_virtual_card(business_card_params) do
      {:ok, business_card} ->
        business_cards = BusinessCards.list_business_cards(user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Virtual card created successfully")
         |> assign(business_cards: business_cards)
         |> push_navigate(to: ~p"/business-cards/#{business_card}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    business_card = BusinessCards.get_business_card!(id, user.id)
    {:ok, _} = BusinessCards.delete_business_card(business_card)

    business_cards = BusinessCards.list_business_cards(user.id)

    {:noreply,
     socket
     |> put_flash(:info, "Business card deleted successfully")
     |> assign(business_cards: business_cards)}
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
          <.header>
            Business Card Details
            <:actions>
              <.link navigate={~p"/business-cards"} class="button">
                <.icon name="hero-arrow-left" class="h-4 w-4" />
                Back to Cards
              </.link>
            </:actions>
          </.header>

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
                      field={%{name: "note[text]", type: "textarea"}}
                      label="Add Note"
                      placeholder="Enter a note about this contact..."
                      rows="3"
                    />
                    <:actions>
                      <.button>Add Note</.button>
                    </:actions>
                  </.simple_form>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <.header>
            Business Cards
            <:actions>
              <.link patch={~p"/business-cards/new"} class="button">
                <.icon name="hero-plus" class="h-4 w-4" />
                Add Card
              </.link>
            </:actions>
          </.header>

          <!-- Search Bar -->
          <div class="mt-6">
            <div class="flex items-center space-x-4">
              <div class="flex-1 max-w-md">
                <form phx-change="search" class="relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
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
                <button
                  phx-click="clear-search"
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4 mr-1" />
                  Clear
                </button>
              <% end %>
            </div>
          </div>

          <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <%= for business_card <- @business_cards do %>
              <div class="bg-white overflow-hidden shadow rounded-lg">
                <div class="p-6">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <div class="h-10 w-10 rounded-full bg-zinc-300 flex items-center justify-center">
                        <span class="text-sm font-medium text-zinc-700">
                          <%= String.first(business_card.name || "?") %>
                        </span>
                      </div>
                    </div>
                    <div class="ml-4 flex-1 min-w-0">
                      <p class="text-sm font-medium text-zinc-900 truncate">
                        <%= business_card.name %>
                      </p>
                      <p class="text-sm text-zinc-500 truncate">
                        <%= business_card.company %>
                      </p>
                    </div>
                    <div class="ml-4 flex-shrink-0">
                      <.link
                        navigate={~p"/business-cards/#{business_card}"}
                        class="text-zinc-400 hover:text-zinc-500"
                      >
                        <.icon name="hero-eye" class="h-5 w-5" />
                      </.link>
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

                  <div class="mt-4 flex justify-between items-center">
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      <%= if business_card.is_virtual, do: "Virtual", else: "Physical" %>
                    </span>

                    <button
                      phx-click="delete"
                      phx-value-id={business_card.id}
                      data-confirm="Are you sure you want to delete this business card?"
                      class="text-red-400 hover:text-red-500"
                    >
                      <.icon name="hero-trash" class="h-4 w-4" />
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if Enum.empty?(@business_cards) do %>
            <div class="text-center py-12">
              <div class="mx-auto h-12 w-12 text-zinc-400">
                <.icon name="hero-identification" class="h-12 w-12" />
              </div>
              <h3 class="mt-2 text-sm font-medium text-zinc-900">No business cards</h3>
              <p class="mt-1 text-sm text-zinc-500">
                Get started by adding your first business card.
              </p>
              <div class="mt-6">
                <.link patch={~p"/business-cards/new"} class="button">
                  <.icon name="hero-plus" class="h-4 w-4" />
                  Add Card
                </.link>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end
end
