defmodule Parsely.OCR.MockClient do
  @moduledoc """
  Mock OCR client for testing purposes.

  This client returns predefined responses without making actual HTTP requests,
  making it ideal for unit tests and development.
  """

  @behaviour Parsely.OCR.Client

  @doc """
  Returns mock OCR results for testing.

  ## Parameters
  - `base64` - The base64 encoded image data (ignored in mock)
  - `opts` - Options for parsing (language is used to determine mock response)

  ## Returns
  - `{:ok, text, meta}` - Mock success response
  """
  def parse_base64_image(_base64, opts \\ []) do
    lang = opts[:language] || "eng"
    start_time = System.monotonic_time(:millisecond)

    {text, meta} = case lang do
      "jpn" ->
        {"田中太郎\n営業部長\n株式会社サンプル\ntanaka@sample.co.jp\n03-1234-5678",
         %{OCRExitCode: 1, ProcessingTimeInMilliseconds: 150}}
      _ ->
        {"John Doe\nSoftware Engineer\nExample Corp\njohn.doe@example.com\n+1 (555) 123-4567",
         %{OCRExitCode: 1, ProcessingTimeInMilliseconds: 200}}
    end

    duration_ms = System.monotonic_time(:millisecond) - start_time

    # Emit telemetry event for mock OCR latency
    :telemetry.execute(
      [:parsely, :ocr, :parse],
      %{duration_ms: duration_ms},
      %{engine: "mock", language: lang, success: true}
    )

    {:ok, text, meta}
  end
end
