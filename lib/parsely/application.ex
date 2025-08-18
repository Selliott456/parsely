defmodule Parsely.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ParselyWeb.Telemetry,
      # Start the Ecto repository
      Parsely.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Parsely.PubSub},
      # Start Finch
      {Finch, name: Parsely.Finch},
      # Start the Endpoint (http/https)
      ParselyWeb.Endpoint
      # Start a worker by calling: Parsely.Worker.start_link(arg)
      # {Parsely.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Parsely.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ParselyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
