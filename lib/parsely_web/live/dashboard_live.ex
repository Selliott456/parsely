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
    <div class="min-h-screen">
              <div class="p-4 flex items-center justify-center">
          <div class="flex flex-col space-y-4 items-center justify-center w-full h-full">
                  <!-- Scan Business Card -->
        <.link navigate={~p"/scan-card"} class="w-[70vw] max-w-md bg-mint-primary/10 rounded-lg shadow-lg border border-gray-300 hover:border-gray-400 hover:shadow-xl hover:shadow-purple-500/25 transition-all duration-200 p-8 flex flex-col items-center justify-center text-center min-h-[40vh]">
                          <div class="flex flex-col items-center space-y-6">
                <svg class="h-16 w-16 text-charcoal" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M12 15.2a3.2 3.2 0 100-6.4 3.2 3.2 0 000 6.4z"/>
                  <path d="M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/>
                </svg>
                <div>
                  <h3 class="text-2xl font-semibold text-charcoal">Scan New Card</h3>
                </div>
              </div>
          </.link>

                  <!-- View Business Cards -->
        <.link navigate={~p"/business-cards"} class="w-[70vw] max-w-md bg-mint-primary/10 rounded-lg shadow-lg border border-gray-300 hover:border-gray-400 hover:shadow-xl hover:shadow-purple-500/25 transition-all duration-200 p-8 flex flex-col items-center justify-center text-center min-h-[40vh]">
            <div class="flex flex-col items-center space-y-6">
              <svg class="h-16 w-16 text-charcoal" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z"/>
              </svg>
              <div>
                <h3 class="text-2xl font-semibold text-charcoal">View Saved Cards</h3>

              </div>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
