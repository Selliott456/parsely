defmodule ParselyWeb.DashboardLive do
  use ParselyWeb, :live_view

  alias Parsely.BusinessCards

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    business_cards = BusinessCards.list_business_cards(user.id)

    {:ok,
     assign(socket,
       business_cards: business_cards,
       page_title: "Dashboard"
     )}
  end



  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl">
      <div class="mb-8">

        <div class="flex space-x-4">
          <!-- Scan Business Card -->
          <.button_link navigate={~p"/scan-card"} class="inline-flex items-center">
            <.icon name="hero-camera" class="h-4 w-4 mr-2" />
            Scan Business Card
          </.button_link>

          <!-- View Business Cards -->
          <.button_link_secondary navigate={~p"/business-cards"} class="inline-flex items-center">
            <.icon name="hero-eye" class="h-4 w-4 mr-2" />
            View Business Cards
          </.button_link_secondary>
        </div>
      </div>
    </div>
    """
  end
end
