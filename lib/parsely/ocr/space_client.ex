defmodule Parsely.OCR.SpaceClient do
  @moduledoc """
  OCR.space API client implementation.

  This client uses the OCR.space API to extract text from images.
  It uses Req for robust HTTP requests with retry logic.
  """

  @behaviour Parsely.OCR.Client

  @endpoint "https://api.ocr.space/parse/image"

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
    lang = opts[:language] || "eng"
    api_key = get_api_key()
    filetype = opts[:filetype] || "jpg"

    body =
      URI.encode_query(%{
        "apikey" => api_key,
        "base64Image" => "data:image/#{filetype};base64,#{base64}",
        "language" => normalize_lang(lang),
        "isOverlayRequired" => "false",
        "filetype" => filetype
      })

    req =
      Req.new(
        url: @endpoint,
        headers: [{"content-type", "application/x-www-form-urlencoded"}],
        receive_timeout: 30_000
      )
      |> Req.Request.put_private(:retry_options, attempts: 3, backoff_base: 100)

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
    case System.fetch_env("OCRSPACE_API_KEY") do
      {:ok, key} when is_binary(key) and byte_size(key) > 0 ->
        key
      _ ->
        # Fallback to hardcoded key for development (should be removed in production)
        "K81724188988957"
    end
  end
end
