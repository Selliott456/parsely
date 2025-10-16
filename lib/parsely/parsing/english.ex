defmodule Parsely.Parsing.English do
  @moduledoc """
  English business card parsing with precompiled regex patterns for optimal performance.

  This module contains all regex patterns compiled at module level to avoid
  recompilation on each use, significantly improving parsing performance.
  """

  # Email patterns
  @email_standard ~r/\b[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}\b/
  @email_with_space ~r/[\w._%+-]+@[\w.-]+\s+[A-Za-z]{2,}/
  @email_multiple_parts ~r/[\w._%+-]+@[\w.-]+\s+[A-Za-z]+\s+[A-Za-z]+/
  @email_validation ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
  @email_cleanup_spaces ~r/\s+/
  @email_cleanup_corn ~r/corn$/
  @email_cleanup_chars ~r/[^\w@.-]/

  # Phone patterns
  @phone_us_standard ~r/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/
  @phone_international ~r/\+\d{1,3}[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/
  @phone_japanese_corrupted ~r/電語:\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_corrupted_separators ~r/\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_japanese_heavy ~r/電語:\+?[^\w]*(\d{1,3})[^\w]*(\d{3})[^\w]*(\d{3})[^\w]*(\d{4})/
  @phone_japanese_single ~r/電語:\+?[^\d]*(\d{1,3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_digits_only ~r/\b\d{10,}\b/
  @phone_formatted ~r/\(\d{3}\)\s*\d{3}-\d{4}/
  @phone_tel_prefix ~r/Tel:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_fax_prefix ~r/Fax:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_mobile_prefix ~r/Mobile:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/
  @phone_cleanup_chars ~r/[^\d+\-().\s]/
  @phone_cleanup_spaces ~r/\s+/
  @phone_digits_extract ~r/[^\d+]/

  # Name patterns
  @name_capitalized ~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/
  @name_mixed_case ~r/^[A-Z][a-z]+\s+[A-Z][a-z]+$/
  @name_all_caps ~r/^[A-Z]+\s+[A-Z]+$/
  @name_single_word ~r/^[A-Z][A-Za-z]+$/
  @name_with_initial ~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+$/
  @name_with_initial_mixed ~r/^[A-Z][a-z]+\s+[A-Z]\.?\s+[A-Z][a-z]+$/
  @name_with_initial_all_caps ~r/^[A-Z]+\s+[A-Z]\.?\s+[A-Z]+$/
  @name_initial_first ~r/^[A-Z]+\.?\s+[A-Z][A-Za-z]+$/
  @name_initial_first_all_caps ~r/^[A-Z]+\.?\s+[A-Z]+$/
  @name_multiple_initials ~r/^[A-Z][A-Za-z]+(\s+[A-Z]\.?)+\s+[A-Z][A-Za-z]+$/
  @name_with_title ~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?$/
  @name_with_title_all_caps ~r/^[A-Z]+\s+[A-Z]+,\s*[A-Z]\.?[A-Z]?\.?$/
  @name_with_credentials ~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?/
  @name_basic ~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/
  @name_cleanup_chars ~r/[^A-Za-z\s\-'.]/
  @name_word_split ~r/\s+/
  @name_word_validation ~r/^[A-Z][a-z]+$|^[A-Z]\.$|^[A-Z]\.?[A-Z]?\.?$/

  # Additional name patterns for titles
  @name_title_with_credentials ~r/^[A-Z][a-z]+\.?\s+[A-Z][a-z]+\s+[A-Z][a-z]+,\s*[A-Z]\.?[A-Z]?\.?$/
  @name_dr_md_pattern ~r/^Dr\.\s+[A-Z][a-z]+\s+[A-Z][a-z]+,\s*M\.D\.$/
  @name_title_pattern ~r/^[A-Z][a-z]+\.\s+[A-Z][a-z]+\s+[A-Z][a-z]+$/

  # Address patterns
  @address_zipcode ~r/\b\d{5}(-\d{4})?\b/
  @address_state ~r/\b[A-Z]{2}\b/
  @address_city_state_zip ~r/[A-Za-z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?/
  @address_city_state_zip_extended ~r/[A-Za-z\s]+,\s*[A-Za-z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?/
  @address_street_number ~r/\d+\s+/
  @address_street_name ~r/\d+\s+[A-Za-z\s]+/
  @address_city ~r/[A-Za-z\s]+,\s*[A-Z]{2}/
  @address_zip ~r/\d{5}(-\d{4})?/
  @address_city_partial ~r/[A-Za-z\s]+\.?\s*\d{3}/

  # Company patterns
  @company_basic ~r/^[A-Z][A-Za-z\s&.-]{2,50}$/
  @company_indicators ~r/\b(inc|ltd|corp|llc|gmbh|co)\b/i

  # Position/Title patterns
  @position_basic ~r/^[A-Z][A-Za-z\s&.-]{2,40}$/
  @position_keywords ~r/\b(engineer|manager|director|president|ceo|cto|cfo|officer|specialist|analyst|consultant)\b/i

  # General patterns
  @has_letters ~r/[A-Za-z]/
  @has_digits ~r/\d/
  @phone_line_check ~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/
  @phone_line_check_extended ~r/\+?\d{10,}/
  @non_letters ~r/^[^A-Za-z]*$/
  @bullet_points ~r/^[•\s«»\-_]+/
  @starts_with_digits ~r/^\d+/
  @all_caps_short ~r/^[A-Z\s]+$/
  @word_split ~r/\s+/
  @email_split ~r/[._-]+/

  # Base64 cleanup
  @base64_cleanup ~r/^data:image\/[^;]+;base64,/
  @line_break_cleanup ~r/\r\n/
  @carriage_return_cleanup ~r/\r/

  @doc """
  Extracts email addresses from text using precompiled patterns.
  """
  def extract_emails(text) do
    text
    |> extract_with_patterns([@email_standard, @email_with_space, @email_multiple_parts])
    |> Enum.map(&clean_email/1)
    |> Enum.filter(&valid_email?/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts phone numbers from text using libphonenumber.
  """
  def extract_phones(text) do
    Parsely.Phone.extract_all(text)
  end

  @doc """
  Extracts names from text using precompiled patterns.
  """
  def extract_names(text) do
    lines = String.split(text, "\n", trim: true)

    lines
    |> Enum.filter(&is_name_line?/1)
    |> Enum.map(&clean_name/1)
    |> Enum.filter(&valid_name?/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts company names from text using precompiled patterns.
  """
  def extract_companies(text) do
    lines = String.split(text, "\n", trim: true)

    lines
    |> Enum.filter(&is_company_line?/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&valid_company?/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts positions/titles from text using precompiled patterns.
  """
  def extract_positions(text) do
    lines = String.split(text, "\n", trim: true)

    lines
    |> Enum.filter(&is_position_line?/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&valid_position?/1)
    |> Enum.uniq()
  end

  @doc """
  Extracts addresses from text using precompiled patterns.
  """
  def extract_addresses(text) do
    lines = String.split(text, "\n", trim: true)

    lines
    |> Enum.filter(&is_address_line?/1)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&valid_address?/1)
    |> Enum.uniq()
  end

  # Private helper functions

  defp extract_with_patterns(text, patterns) do
    patterns
    |> Enum.flat_map(&Regex.scan(&1, text))
    |> Enum.map(fn [match | _] -> match end)
    |> Enum.uniq()
  end

  defp clean_email(email) do
    email
    |> String.replace(@email_cleanup_spaces, "")
    |> String.replace(@email_cleanup_corn, ".com")
    |> String.replace(@email_cleanup_chars, "")
  end

  defp valid_email?(email) do
    Regex.match?(@email_validation, email)
  end


  defp is_name_line?(line) do
    cond do
      # Basic name patterns
      Regex.match?(@name_capitalized, line) -> true
      Regex.match?(@name_mixed_case, line) -> true
      Regex.match?(@name_all_caps, line) -> true
      Regex.match?(@name_single_word, line) -> true

      # Names with initials
      Regex.match?(@name_with_initial, line) -> true
      Regex.match?(@name_with_initial_mixed, line) -> true
      Regex.match?(@name_with_initial_all_caps, line) -> true
      Regex.match?(@name_initial_first, line) -> true
      Regex.match?(@name_initial_first_all_caps, line) -> true
      Regex.match?(@name_multiple_initials, line) -> true

      # Names with titles/credentials
      Regex.match?(@name_with_title, line) -> true
      Regex.match?(@name_with_title_all_caps, line) -> true
      Regex.match?(@name_with_credentials, line) -> true

      # Additional patterns for titles like "Dr. Jane Smith, M.D."
      Regex.match?(@name_title_with_credentials, line) -> true
      # Pattern for "Dr. Jane Smith, M.D." specifically
      Regex.match?(@name_dr_md_pattern, line) -> true
      # Pattern for titles like "Dr. Jane Smith"
      Regex.match?(@name_title_pattern, line) -> true

      true -> false
    end
  end

  defp clean_name(name) do
    name
    |> String.replace(@name_cleanup_chars, "")
    |> String.split(@name_word_split, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.join(" ")
  end

  defp valid_name?(name) do
    words = String.split(name, @name_word_split, trim: true)

    cond do
      length(words) < 2 -> false
      length(words) > 6 -> false  # Allow more words for titles like "Dr. Jane Smith, M.D."
      # For titles with credentials, be more lenient
      String.contains?(name, ",") -> true
      not Enum.all?(words, &Regex.match?(@name_word_validation, &1)) -> false
      true -> true
    end
  end

  defp is_company_line?(line) do
    cond do
      # Skip obvious non-company lines
      Regex.match?(@non_letters, line) -> false
      Regex.match?(@bullet_points, line) -> false
      Regex.match?(@starts_with_digits, line) -> false
      String.length(line) > 50 -> false

      # Check for company indicators
      Regex.match?(@company_indicators, line) -> true

      # Check basic company pattern
      Regex.match?(@company_basic, line) and
      length(String.split(line, @word_split, trim: true)) in 1..4 -> true

      true -> false
    end
  end

  defp valid_company?(company) do
    String.length(company) >= 2 and String.length(company) <= 50
  end

  defp is_position_line?(line) do
    cond do
      # Skip obvious non-position lines
      Regex.match?(@non_letters, line) -> false
      Regex.match?(@bullet_points, line) -> false
      Regex.match?(@starts_with_digits, line) -> false
      String.length(line) > 40 -> false

      # Check for position keywords
      Regex.match?(@position_keywords, line) -> true

      # Check basic position pattern
      Regex.match?(@position_basic, line) and
      length(String.split(line, @word_split, trim: true)) in 1..3 -> true

      true -> false
    end
  end

  defp valid_position?(position) do
    String.length(position) >= 2 and String.length(position) <= 40
  end

  defp is_address_line?(line) do
    cond do
      # Skip obvious non-address lines
      not Regex.match?(@has_digits, line) -> false
      String.length(line) > 100 -> false

      # Check for address indicators
      Regex.match?(@address_zipcode, line) -> true
      Regex.match?(@address_state, line) -> true
      Regex.match?(@address_city_state_zip, line) -> true
      Regex.match?(@address_city_state_zip_extended, line) -> true

      # Check for street patterns
      Regex.match?(@address_street_number, line) -> true
      Regex.match?(@address_street_name, line) -> true

      true -> false
    end
  end

  defp valid_address?(address) do
    cond do
      # Must have some letters and numbers
      not Regex.match?(@has_letters, address) -> false
      not Regex.match?(@has_digits, address) -> false

      # Check for specific address patterns
      Regex.match?(@address_zipcode, address) -> true
      Regex.match?(@address_state, address) -> true
      Regex.match?(@address_city, address) -> true
      Regex.match?(@address_street_number, address) -> true

      true -> false
    end
  end

  @doc """
  Cleans base64 image data by removing data URI prefix.
  """
  def clean_base64_data(base64_image) do
    String.replace(base64_image, @base64_cleanup, "")
  end

  @doc """
  Normalizes line breaks in text.
  """
  def normalize_line_breaks(text) do
    text
    |> String.replace(@line_break_cleanup, "\n")
    |> String.replace(@carriage_return_cleanup, "\n")
    |> String.trim_trailing()
  end
end
