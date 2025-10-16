defmodule Parsely.OCR.Client do
  @moduledoc """
  Behaviour for OCR clients that can parse base64 encoded images.

  This behaviour allows for different OCR implementations to be used
  interchangeably, making the system more testable and flexible.
  """

  @doc """
  Parses a base64 encoded image and returns the extracted text.

  ## Parameters
  - `base64` - The base64 encoded image data (without data URI prefix)
  - `opts` - Options for parsing, including:
    - `:language` - Language code (e.g., "eng", "jpn", "eng,jpn")
    - `:filetype` - File type (e.g., "jpg", "png")

  ## Returns
  - `{:ok, text, meta}` - Success with extracted text and metadata
  - `{:error, reason}` - Error with reason
  """
  @callback parse_base64_image(base64 :: binary(), opts :: keyword()) ::
              {:ok, text :: binary(), meta :: map()} | {:error, term()}
end
