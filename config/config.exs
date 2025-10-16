# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project. If another project (or dependency)
# is using this project as a dependency, the config
# files in the dependency are not automatically loaded.
# See the Config module documentation for more information.

# General application configuration
import Config

# Configures the endpoint
config :parsely, ParselyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: ParselyWeb.ErrorHTML, json: ParselyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Parsely.PubSub,
  live_view: [signing_salt: "your_signing_salt_here"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# OCR Configuration
config :parsely, :ocr_client, :space  # Options: :space, :mock, :tesseract

# OCR HTTP Client Configuration
config :parsely, :ocr,
  timeout: 30_000,
  receive_timeout: 30_000,
  connect_timeout: 10_000,
  retry_attempts: 3,
  retry_backoff_base: 100,
  retry_backoff_max: 5_000,
  circuit_breaker: [
    failure_threshold: 5,
    recovery_timeout: 60_000,
    half_open_max_calls: 3
  ],
  rate_limit: [
    max_requests: 500,  # OCR.space free tier limit
    window_ms: 3_600_000  # 1 hour window
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
