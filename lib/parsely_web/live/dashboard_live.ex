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

  def handle_event("view-business-cards", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/business-cards")}
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


          <!-- View Business Cards -->
          <button
            phx-click="view-business-cards"
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
          >
            <.icon name="hero-eye" class="h-4 w-4 mr-2" />
            View Business Cards
          </button>
        </div>
      </div>

      <!-- Quick Stats -->
      <div class="bg-white rounded-lg border border-zinc-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Quick Stats</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600"><%= length(@business_cards) %></div>
            <div class="text-sm text-gray-600">Total Business Cards</div>
          </div>
          <div class="text-center">
            <div class="text-2xl font-bold text-purple-600">
              <%= length(@business_cards) %>
            </div>
            <div class="text-sm text-gray-600">Scanned Cards</div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
