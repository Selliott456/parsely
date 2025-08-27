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
          <.button_primary phx-click="scan-card" class="inline-flex items-center">
            <.icon name="hero-camera" class="h-4 w-4 mr-2" />
            Scan Business Card
          </.button_primary>

          <!-- View Business Cards -->
          <.button_secondary phx-click="view-business-cards" class="inline-flex items-center">
            <.icon name="hero-eye" class="h-4 w-4 mr-2" />
            View Business Cards
          </.button_secondary>
        </div>
      </div>
    </div>
    """
  end
end
