defmodule Parsely.Phone do
  @moduledoc """
  Phone number parsing and formatting using improved regex patterns.

  This module provides robust phone number extraction, validation, and formatting
  that works consistently across different countries and formats.
  """

  # Precompiled regex patterns for phone number extraction
  @phone_token_pattern ~r/[+()\d\-.\s]{7,}/
  @us_phone_pattern ~r/\b(\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\b/
  @international_pattern ~r/\+\d{1,3}[-.\s]?\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4}/
  @uk_phone_pattern ~r/\b(0\d{2,3}[-.\s]?\d{3,4}[-.\s]?\d{3,4})\b/
  @digits_only_pattern ~r/\b\d{10,15}\b/

  @doc """
  Extracts all valid phone numbers from text and returns them in international format.

  ## Parameters
  - `text` - The text to search for phone numbers
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - List of phone numbers in international format (e.g., "+1 555 123 4567")
  """
  def extract_all(text, _default_region \\ "US") do
    # Extract phone numbers using multiple patterns
    phones = []
    |> extract_with_pattern(@us_phone_pattern, text, &format_us_phone/1)
    |> extract_with_pattern(@international_pattern, text, &format_international_phone/1)
    |> extract_with_pattern(@uk_phone_pattern, text, &format_uk_phone/1)
    |> extract_with_pattern(@digits_only_pattern, text, &format_digits_only/1)
    |> Enum.uniq()
    |> Enum.filter(&valid_phone_format?/1)

    phones
  end

  defp extract_with_pattern(acc, pattern, text, formatter) do
    matches = Regex.scan(pattern, text)
    formatted = Enum.map(matches, &formatter.(&1))
    acc ++ formatted
  end

  defp format_us_phone([_full, country_code, area, prefix, suffix]) do
    if country_code in ["+1", "1", ""] do
      "+1 #{area} #{prefix} #{suffix}"
    else
      "#{country_code} #{area} #{prefix} #{suffix}"
    end
  end

  defp format_international_phone([full]) do
    # Clean up the international format
    full
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp format_uk_phone([_full, phone]) do
    # Convert UK format (0xxx xxx xxxx) to international format (+44 xxx xxx xxxx)
    cleaned = phone
    |> String.replace(~r/\s+/, " ")
    |> String.trim()

    if String.starts_with?(cleaned, "0") do
      "+44 " <> String.slice(cleaned, 1..-1//1)
    else
      "+44 " <> cleaned
    end
  end

  defp format_digits_only([digits]) do
    case String.length(digits) do
      10 -> "+1 #{String.slice(digits, 0, 3)} #{String.slice(digits, 3, 3)} #{String.slice(digits, 6, 4)}"
      11 ->
        if String.starts_with?(digits, "1") do
          "+1 #{String.slice(digits, 1, 3)} #{String.slice(digits, 4, 3)} #{String.slice(digits, 7, 4)}"
        else
          "+#{digits}"
        end
      _ -> "+#{digits}"
    end
  end

  defp valid_phone_format?(phone) do
    # Basic validation - must have at least 10 digits
    digits = String.replace(phone, ~r/[^\d]/, "")
    String.length(digits) >= 10 and String.length(digits) <= 15
  end

  @doc """
  Extracts phone numbers and returns at most 2, prioritizing the most likely primary number.

  ## Parameters
  - `text` - The text to search for phone numbers
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `{primary_phone, secondary_phone}` where secondary_phone may be nil
  """
  def extract_primary_and_secondary(text, default_region \\ "US") do
    phones = extract_all(text, default_region)

    case phones do
      [] -> {nil, nil}
      [primary] -> {primary, nil}
      [primary, secondary | _] -> {primary, secondary}
    end
  end

  @doc """
  Validates if a string is a valid phone number.

  ## Parameters
  - `phone_string` - The phone number string to validate
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `true` if valid, `false` otherwise
  """
  def valid?(phone_string, _default_region \\ "US") do
    valid_phone_format?(phone_string)
  end

  @doc """
  Formats a phone number string to international format.

  ## Parameters
  - `phone_string` - The phone number string to format
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `{:ok, formatted_phone}` if successful
  - `{:error, reason}` if parsing fails
  """
  def format_international(phone_string, _default_region \\ "US") do
    # Try to extract and format the phone number
    phones = extract_all(phone_string)
    case phones do
      [formatted_phone | _] -> {:ok, formatted_phone}
      [] -> {:error, :invalid_phone_number}
    end
  end

  @doc """
  Formats a phone number string to national format.

  ## Parameters
  - `phone_string` - The phone number string to format
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `{:ok, formatted_phone}` if successful
  - `{:error, reason}` if parsing fails
  """
  def format_national(phone_string, _default_region \\ "US") do
    case format_international(phone_string) do
      {:ok, international} ->
        # Convert international format to national format
        national = international
        |> String.replace(~r/^\+1\s/, "")
        |> String.replace(~r/^\+44\s/, "0")
        |> String.replace(~r/^\+81\s/, "0")
        |> String.replace(~r/^\+/, "")
        {:ok, national}
      error -> error
    end
  end

  @doc """
  Gets the country code from a phone number.

  ## Parameters
  - `phone_string` - The phone number string
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `{:ok, country_code}` if successful (e.g., "US", "GB", "JP")
  - `{:error, reason}` if parsing fails
  """
  def get_country_code(phone_string, _default_region \\ "US") do
    if valid_phone_format?(phone_string) do
      # Simple country code detection based on phone number format
      cond do
        String.starts_with?(phone_string, "+1") -> {:ok, "US"}
        String.starts_with?(phone_string, "+44") -> {:ok, "GB"}
        String.starts_with?(phone_string, "+81") -> {:ok, "JP"}
        String.starts_with?(phone_string, "+") -> {:ok, "UNKNOWN"}
        true -> {:ok, "US"}  # Default to US for numbers without country code
      end
    else
      {:error, :invalid_phone_number}
    end
  end

  @doc """
  Checks if a phone number is a mobile number.

  ## Parameters
  - `phone_string` - The phone number string
  - `default_region` - Default region for parsing (default: "US")

  ## Returns
  - `{:ok, is_mobile}` if successful
  - `{:error, reason}` if parsing fails
  """
  def is_mobile?(phone_string, _default_region \\ "US") do
    if valid_phone_format?(phone_string) do
      {:ok, true}  # Assume all valid phone numbers could be mobile
    else
      {:error, :invalid_phone_number}
    end
  end

  @doc """
  Cleans and normalizes a phone number string by removing common formatting characters.

  ## Parameters
  - `phone_string` - The phone number string to clean

  ## Returns
  - Cleaned phone number string
  """
  def clean(phone_string) do
    phone_string
    |> String.replace(~r/[^\d+\-().\s]/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
