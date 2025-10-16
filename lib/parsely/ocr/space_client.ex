defmodule Parsely.OCR.SpaceClient do
  @moduledoc """
  OCR.space API client implementation.

  This client uses the OCR.space API to extract text from images.
  It uses Req for robust HTTP requests with retry logic and circuit breaker protection.
  """

  @behaviour Parsely.OCR.Client

  require Logger

  @doc """
  Parses a base64 encoded image using the OCR.space API.

  ## Parameters
  - `base64` - The base64 encoded image data (without data URI prefix)
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")
    - `:filetype` - File type (default: "jpg")

  ## Returns
  - `{:ok, text, meta}` - Success with extracted text and metadata
  - `{:error, reason}` - Error with reason
  """
  def parse_base64_image(base64, opts \\ []) do
    # Use circuit breaker to protect against API failures
    circuit_breaker_call = fn ->
      do_parse_base64_image(base64, opts)
    end

    case Parsely.OCR.CircuitBreaker.call(circuit_breaker_call) do
      {:ok, result} -> result
      {:error, :circuit_open} ->
        Logger.warning("OCR API circuit breaker is open, request rejected")
        {:error, :service_unavailable}
      {:error, :rate_limit_exceeded} ->
        Logger.warning("OCR API rate limit exceeded")
        {:error, :rate_limit_exceeded}
      {:error, :api_failure} ->
        {:error, :api_failure}
    end
  end

  defp do_parse_base64_image(base64, opts) do
    lang = opts[:language] || "eng"
    api_key = get_api_key()
    filetype = opts[:filetype] || "jpg"
    endpoint = get_endpoint()

    body =
      URI.encode_query(%{
        "apikey" => api_key,
        "base64Image" => "data:image/#{filetype};base64,#{base64}",
        "language" => normalize_lang(lang),
        "isOverlayRequired" => "false",
        "filetype" => filetype
      })

    config = Application.get_env(:parsely, :ocr, [])

    req =
      Req.new(
        url: endpoint,
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        timeout: Keyword.get(config, :timeout, 30_000),
        receive_timeout: Keyword.get(config, :receive_timeout, 30_000),
        connect_timeout: Keyword.get(config, :connect_timeout, 10_000)
      )
      |> Req.Request.put_private(:retry_options,
        attempts: Keyword.get(config, :retry_attempts, 3),
        backoff_base: Keyword.get(config, :retry_backoff_base, 100),
        backoff_max: Keyword.get(config, :retry_backoff_max, 5_000)
      )

    with {:ok, %Req.Response{status: 200, body: response_body}} <- Req.post(req, body: body),
         {:ok, %{"ParsedResults" => [%{"ParsedText" => text} | _], "IsErroredOnProcessing" => false} = json} <- Jason.decode(response_body) do
      meta = Map.take(json, ~w(OCRExitCode ProcessingTimeInMilliseconds)a)
      {:ok, text, meta}
    else
      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}
      {:error, %Req.TransportError{} = err} ->
        {:error, {:transport, err.reason}}
      {:ok, %{"IsErroredOnProcessing" => true, "ErrorMessage" => error_msg}} ->
        {:error, {:api_error, error_msg}}
      {:ok, %{"ParsedResults" => []}} ->
        {:error, :no_text_found}
      {:ok, _other} ->
        {:error, :unexpected_response}
      {:error, decode_err} ->
        {:error, {:decode_error, decode_err}}
    end
  end

  @doc """
  Normalizes language codes to OCR.space format.
  """
  def normalize_lang(lang) do
    case lang do
      "eng" -> "eng"
      "jpn" -> "jpn"
      "eng,jpn" -> "eng,jpn"
      "jpn,eng" -> "jpn,eng"
      _ -> "eng"
    end
  end

  defp get_api_key do
    # First try runtime config (from environment variables)
    case Application.get_env(:parsely, :ocr)[:api_key] do
      nil ->
        # Fallback to direct environment variable
        case System.fetch_env!("OCRSPACE_API_KEY") do
          key when is_binary(key) and byte_size(key) > 0 ->
            key
        end
      key when is_binary(key) and byte_size(key) > 0 ->
        key
      _ ->
        raise "OCRSPACE_API_KEY environment variable is required but not set"
    end
  end

  defp get_endpoint do
    # First try runtime config (from environment variables)
    case Application.get_env(:parsely, :ocr)[:endpoint] do
      nil ->
        # Fallback to default
        "https://api.ocr.space/parse/image"
      endpoint when is_binary(endpoint) ->
        endpoint
      _ ->
        "https://api.ocr.space/parse/image"
    end
  end
end
