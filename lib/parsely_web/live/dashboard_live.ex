defmodule ParselyWeb.DashboardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards
  alias Parsely.BusinessCards.BusinessCard

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:ok,
     assign(socket,
       business_cards: business_cards,
       page_title: "Dashboard"
     )}
  end

  def handle_event("scan-card", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/scan-card")}
  end

  def handle_event("add-manually", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manual-entry")}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900 mb-4">Dashboard</h1>

        <div class="flex space-x-4">
          <!-- Scan Business Card -->
          <button
            phx-click="scan-card"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-camera" class="h-4 w-4 mr-2" />
            Scan Business Card
          </button>

          <!-- Add Manually -->
          <button
            phx-click="add-manually"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
          >
            <.icon name="hero-pencil-square" class="h-4 w-4 mr-2" />
            Add Manually
          </button>
        </div>
      </div>

      <!-- Business Cards List -->
      <div class="bg-white rounded-lg border border-zinc-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Your Business Cards</h2>

        <%= if Enum.empty?(@business_cards) do %>
          <p class="text-gray-500">No business cards yet. Add your first one!</p>
        <% else %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for card <- @business_cards do %>
              <div class="border border-gray-200 rounded-lg p-4">
                <h3 class="font-medium text-gray-900"><%= card.name %></h3>
                <p class="text-sm text-gray-600"><%= card.position %></p>
                <p class="text-sm text-gray-600"><%= card.company %></p>
                <p class="text-sm text-gray-600"><%= card.email %></p>
                <p class="text-sm text-gray-600"><%= card.phone %></p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
