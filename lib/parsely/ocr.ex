defmodule Parsely.OCR do
  @moduledoc """
  OCR service module that provides a unified interface for text extraction.

  This module acts as a facade that delegates to the configured OCR client,
  making it easy to switch between different OCR providers.
  """

  @doc """
  Extracts text from a base64 encoded image using the configured OCR client.

  ## Parameters
  - `base64_image` - The base64 encoded image data (with or without data URI prefix)
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")
    - `:filetype` - File type (default: "jpg")
    - `:client` - Override the default client (for testing)

  ## Returns
  - `{:ok, text, meta}` - Success with extracted text and metadata
  - `{:error, reason}` - Error with reason
  """
  def extract_text(base64_image, opts \\ []) do
    client = opts[:client] || default_client()
    clean_base64 = clean_base64_data(base64_image)

    client.parse_base64_image(clean_base64, opts)
  end

  @doc """
  Extracts business card information from a base64 encoded image.
  Returns the result in map format for backward compatibility.

  ## Parameters
  - `base64_image` - The base64 encoded image data
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")
    - `:client` - Override the default client (for testing)

  ## Returns
  - `{:ok, business_card_data}` - Success with parsed business card data (map format)
  - `{:error, reason}` - Error with reason
  """
  def extract_business_card_info(base64_image, opts \\ []) do
    case extract_business_card_struct(base64_image, opts) do
      {:ok, business_card} -> {:ok, Parsely.BusinessCard.to_map(business_card)}
      error -> error
    end
  end

  @doc """
  Extracts business card information from a base64 encoded image.
  Returns a Parsely.BusinessCard struct with confidence scores.

  ## Parameters
  - `base64_image` - The base64 encoded image data
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")
    - `:client` - Override the default client (for testing)

  ## Returns
  - `{:ok, %Parsely.BusinessCard{}}` - Success with parsed business card struct
  - `{:error, reason}` - Error with reason
  """
  def extract_business_card_struct(base64_image, opts \\ []) do
    language = opts[:language] || "eng"

    with {:ok, text, _meta} <- extract_text(base64_image, opts) do
      Parsely.Parsing.BusinessCardParser.parse(text, language: language)
    end
  end

  # Private functions

  defp default_client do
    case Application.get_env(:parsely, :ocr_client, :space) do
      :space -> Parsely.OCR.SpaceClient
      :mock -> Parsely.OCR.MockClient
      :tesseract -> Parsely.OCR.TesseractClient
      client when is_atom(client) -> client
    end
  end

  defp clean_base64_data(base64_image) do
    base64_image
    |> String.replace(~r/^data:image\/[^;]+;base64,/, "")
  end

end
