defmodule Parsely.Parsing.BusinessCardParser do
  @moduledoc """
  Pure parsing module for extracting business card information from text.

  This module contains all the parsing logic separated from HTTP concerns,
  making it easy to test and reason about.
  """

  alias Parsely.BusinessCard

  @doc """
  Parses business card text and extracts structured information.

  ## Parameters
  - `text` - The raw text extracted from the business card image
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")

  ## Returns
  - `{:ok, %Parsely.BusinessCard{}}` - Success with parsed business card struct
  - `{:error, reason}` - Error with reason
  """
  def parse(text, opts \\ []) do
    language = opts[:language] || "eng"

    # Clean up the text
    clean_text = text
      |> String.replace(~r/\r\n/, "\n")
      |> String.replace(~r/\r/, "\n")
      |> String.trim()

    # Route to appropriate parser based on language
    if String.contains?(language, "jpn") do
      parse_japanese_business_card(clean_text, language)
    else
      parse_english_business_card(clean_text, language)
    end
  end

  defp parse_english_business_card(text, language) do
    # Get the raw parsing result from OCRService
    case Parsely.OCRService.parse_english_business_card(text) do
      {:ok, result} ->
        # Convert to BusinessCard struct with confidence scores
        business_card = result
        |> Map.put(:language, language)
        |> convert_to_business_card_struct()

        {:ok, business_card}

      error ->
        error
    end
  end

  defp parse_japanese_business_card(text, language) do
    # Get the raw parsing result from JapaneseOCRService
    case Parsely.JapaneseOCRService.parse_business_card_text(text) do
      {:ok, result} ->
        # Convert to BusinessCard struct with confidence scores
        business_card = result
        |> Map.put(:language, language)
        |> convert_to_business_card_struct()

        {:ok, business_card}

      error ->
        error
    end
  end

  defp convert_to_business_card_struct(result) do
    # Convert phones to list format
    phones = case {result[:primary_phone], result[:secondary_phone]} do
      {nil, nil} -> nil
      {primary, nil} -> [primary]
      {nil, secondary} -> [secondary]
      {primary, secondary} -> [primary, secondary]
    end

    # Calculate confidence scores based on extraction quality
    confidence = %{
      name: calculate_name_confidence(result[:name]),
      email: calculate_email_confidence(result[:email]),
      phones: calculate_phones_confidence(phones),
      company: calculate_company_confidence(result[:company]),
      position: calculate_position_confidence(result[:position]),
      address: calculate_address_confidence(result[:address])
    }

    BusinessCard.new(result[:raw_text] || "",
      name: result[:name],
      email: result[:email],
      phones: phones,
      company: result[:company],
      position: result[:position],
      address: result[:address],
      language: result[:language],
      confidence: confidence
    )
  end

  # Confidence calculation functions
  defp calculate_name_confidence(nil), do: 0.0
  defp calculate_name_confidence(name) when is_binary(name) do
    cond do
      # High confidence: proper name format with 2+ words
      Regex.match?(~r/^[A-Z][a-z]+\s+[A-Z][a-z]+/, name) -> 0.9
      # Medium confidence: capitalized words
      Regex.match?(~r/^[A-Z]/, name) -> 0.7
      # Lower confidence: mixed case or single word
      true -> 0.5
    end
  end

  defp calculate_email_confidence(nil), do: 0.0
  defp calculate_email_confidence(email) when is_binary(email) do
    if Regex.match?(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/, email) do
      0.95  # Very high confidence for valid email format
    else
      0.3   # Low confidence for malformed email
    end
  end

  defp calculate_phones_confidence(nil), do: 0.0
  defp calculate_phones_confidence(phones) when is_list(phones) do
    # Calculate average confidence of all phone numbers
    phones
    |> Enum.map(&calculate_single_phone_confidence/1)
    |> Enum.sum()
    |> Kernel./(length(phones))
  end

  defp calculate_single_phone_confidence(phone) when is_binary(phone) do
    cond do
      # High confidence: properly formatted phone numbers
      Regex.match?(~r/^\(\d{3}\)\s*\d{3}-\d{4}$/, phone) -> 0.9
      Regex.match?(~r/^\+\d{1,3}[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}$/, phone) -> 0.9
      # Medium confidence: has enough digits
      Regex.match?(~r/\d{10,}/, phone) -> 0.7
      # Lower confidence: shorter numbers
      true -> 0.4
    end
  end

  defp calculate_company_confidence(nil), do: 0.0
  defp calculate_company_confidence(company) when is_binary(company) do
    cond do
      # High confidence: contains company indicators
      Regex.match?(~r/\b(inc|ltd|corp|llc|gmbh|co)\b/i, company) -> 0.9
      # Medium confidence: proper capitalization and reasonable length
      Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{3,50}$/, company) -> 0.7
      # Lower confidence: short or unusual format
      true -> 0.5
    end
  end

  defp calculate_position_confidence(nil), do: 0.0
  defp calculate_position_confidence(position) when is_binary(position) do
    # Common job title keywords
    title_keywords = ~w(engineer manager director president ceo cto cfo officer specialist analyst consultant)

    cond do
      # High confidence: contains job title keywords
      Enum.any?(title_keywords, &String.contains?(String.downcase(position), &1)) -> 0.8
      # Medium confidence: proper capitalization
      Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{2,40}$/, position) -> 0.6
      # Lower confidence
      true -> 0.4
    end
  end

  defp calculate_address_confidence(nil), do: 0.0
  defp calculate_address_confidence(address) when is_binary(address) do
    # Address indicators
    address_indicators = ~w(street st avenue ave road rd drive dr lane ln way suite apt)

    cond do
      # High confidence: contains address indicators and numbers
      Enum.any?(address_indicators, &String.contains?(String.downcase(address), &1)) and
      Regex.match?(~r/\d/, address) -> 0.8
      # Medium confidence: has numbers (likely street number)
      Regex.match?(~r/\d/, address) -> 0.6
      # Lower confidence
      true -> 0.3
    end
  end
end
