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

  def handle_event("add-manually", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/manual-entry")}
  end



  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl">

      <!-- Quick Actions Section -->
      <div class="mb-8">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Add with Camera -->
          <div class="bg-white rounded-lg border border-zinc-200 p-6 hover:shadow-md transition-shadow">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <div class="h-12 w-12 bg-blue-100 rounded-lg flex items-center justify-center">
                  <.icon name="hero-camera" class="h-6 w-6 text-blue-600" />
                </div>
              </div>
            </div>
            <div class="mt-4">
              <.link
                navigate={~p"/business-cards/new?method=camera"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <.icon name="hero-camera" class="h-4 w-4 mr-2" />
                Scan Card
              </.link>
            </div>
          </div>

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




    </div>
    """
  end
end
