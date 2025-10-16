defmodule Parsely.Parsing.BusinessCardParser do
  @moduledoc """
  Pure parsing module for extracting business card information from text.

  This module contains all the parsing logic separated from HTTP concerns,
  making it easy to test and reason about.
  """

  alias Parsely.BusinessCard

  # Precompiled regex patterns for confidence calculation
  @name_mixed_case_pattern ~r/^[A-Z][a-z]+\s+[A-Z][a-z]+$/
  @name_capitalized_pattern ~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/
  @email_validation_pattern ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
  @phone_formatted_pattern ~r/^\(\d{3}\)\s*\d{3}-\d{4}$/
  @phone_international_pattern ~r/^\+\d{1,3}[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}$/
  @phone_digits_pattern ~r/\d{10,}/
  @company_indicators_pattern ~r/\b(inc|ltd|corp|llc|gmbh|co)\b/i
  @company_basic_pattern ~r/^[A-Z][A-Za-z\s&.-]{3,50}$/
  @position_keywords_pattern ~r/\b(engineer|manager|director|president|ceo|cto|cfo|officer|specialist|analyst|consultant)\b/i
  @position_basic_pattern ~r/^[A-Z][A-Za-z\s&.-]{2,40}$/
  @address_zipcode_pattern ~r/\b\d{5}(-\d{4})?\b/
  @address_state_pattern ~r/\b[A-Z]{2}\b/
  @has_digits_pattern ~r/\d/

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
    # Use the new English parsing module with precompiled regexes
    with {:ok, result} <- parse_english_text(text) do
      # Convert to BusinessCard struct with confidence scores
      business_card = result
      |> Map.put(:language, language)
      |> convert_to_business_card_struct()

      {:ok, business_card}
    end
  end

  defp parse_english_text(text) do
    # Use the new English parsing module for better performance
    clean_text = Parsely.Parsing.English.normalize_line_breaks(text)

    # Extract all fields using precompiled regexes
    emails = Parsely.Parsing.English.extract_emails(clean_text)
    names = Parsely.Parsing.English.extract_names(clean_text)
    companies = Parsely.Parsing.English.extract_companies(clean_text)
    positions = Parsely.Parsing.English.extract_positions(clean_text)
    addresses = Parsely.Parsing.English.extract_addresses(clean_text)

    # Extract phone numbers using libphonenumber (at most 2)
    {primary_phone, secondary_phone} = Parsely.Phone.extract_primary_and_secondary(clean_text)

    # Build result map
    result = %{
      name: List.first(names),
      email: List.first(emails),
      primary_phone: primary_phone,
      secondary_phone: secondary_phone,
      company: List.first(companies),
      position: List.first(positions),
      address: List.first(addresses),
      raw_text: clean_text
    }

    {:ok, result}
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

  # Confidence calculation functions using precompiled regexes
  defp calculate_name_confidence(nil), do: 0.0
  defp calculate_name_confidence(name) when is_binary(name) do
    cond do
      # High confidence: proper name format with 2+ words
      Regex.match?(@name_mixed_case_pattern, name) -> 0.9
      # Medium confidence: capitalized words
      Regex.match?(@name_capitalized_pattern, name) -> 0.7
      # Lower confidence: mixed case or single word
      true -> 0.5
    end
  end

  defp calculate_email_confidence(nil), do: 0.0
  defp calculate_email_confidence(email) when is_binary(email) do
    if Regex.match?(@email_validation_pattern, email) do
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
      # High confidence: valid phone number using libphonenumber
      Parsely.Phone.valid?(phone) -> 0.95
      # Medium confidence: looks like a phone number but not valid
      Regex.match?(@phone_digits_pattern, phone) -> 0.6
      # Lower confidence: doesn't look like a phone number
      true -> 0.2
    end
  end

  defp calculate_company_confidence(nil), do: 0.0
  defp calculate_company_confidence(company) when is_binary(company) do
    cond do
      # High confidence: contains company indicators
      Regex.match?(@company_indicators_pattern, company) -> 0.9
      # Medium confidence: proper capitalization and reasonable length
      Regex.match?(@company_basic_pattern, company) -> 0.7
      # Lower confidence: short or unusual format
      true -> 0.5
    end
  end

  defp calculate_position_confidence(nil), do: 0.0
  defp calculate_position_confidence(position) when is_binary(position) do
    cond do
      # High confidence: contains job title keywords
      Regex.match?(@position_keywords_pattern, position) -> 0.8
      # Medium confidence: proper capitalization
      Regex.match?(@position_basic_pattern, position) -> 0.6
      # Lower confidence
      true -> 0.4
    end
  end

  defp calculate_address_confidence(nil), do: 0.0
  defp calculate_address_confidence(address) when is_binary(address) do
    cond do
      # High confidence: contains address indicators and numbers
      (Regex.match?(@address_zipcode_pattern, address) or
       Regex.match?(@address_state_pattern, address)) and
      Regex.match?(@has_digits_pattern, address) -> 0.8
      # Medium confidence: has numbers (likely street number)
      Regex.match?(@has_digits_pattern, address) -> 0.6
      # Lower confidence
      true -> 0.3
    end
  end
end
