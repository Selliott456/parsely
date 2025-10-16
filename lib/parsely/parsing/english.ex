defmodule Parsely.Parsing.English do
  @moduledoc """
  English business card parsing with precompiled regex patterns for optimal performance.

  This module contains all regex patterns compiled at module level to avoid
  recompilation on each use, significantly improving parsing performance.
  """

  # Email patterns
  @email ~r/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i
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

  # Additional patterns for scoring-based extraction
  @name_mixed_case_pattern ~r/^[A-Z][a-z]+(\s+[A-Z]\.?\s*)*[A-Z][a-z]+$/
  @all_caps_short ~r/^[A-Z\s]+$/
  @position_pattern ~r/\b[A-Z][A-Za-z\s]+(?:Engineer|Manager|Director|President|CEO|CTO|CFO|VP|Vice President|Senior|Lead|Principal|Architect|Developer|Analyst|Consultant|Specialist|Coordinator|Supervisor|Head|Chief|Executive|Officer)\b/
  @company_pattern ~r/\b[A-Z][A-Za-z\s&]+(?:Inc|Corp|LLC|Ltd|Co|Company|Corporation|Limited|Group|Associates|Partners|Enterprises|Solutions|Systems|Technologies|Services|Consulting|International|Global|Worldwide)\.?\b/

  # Street keywords for address detection
  @street_keywords ~r/(?:St|Street|Ave|Avenue|Rd|Road|Blvd|Boulevard|Dr|Drive|Ln|Lane|Ct|Court|Pl|Place|Way|Circle|Crescent|Terrace|Trail|Parkway|Highway|Freeway)/i

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
  Extracts email addresses and returns {email, confidence} tuple.
  """
  def email(text) do
    case Regex.run(@email, text) do
      [raw] ->
        cleaned =
          raw
          |> String.replace(~r/\s+/, "")
          |> String.replace(~r/(\.c|,)orn\b/i, ".com") # safer than replacing any "corn"
          |> String.trim()

        if Regex.match?(@email, cleaned), do: {cleaned, 0.98}, else: {nil, 0.0}
      _ -> {nil, 0.0}
    end
  end

  @doc """
  Extracts phone numbers from text using libphonenumber.
  """
  def extract_phones(text) do
    Parsely.Phone.extract_all(text)
  end

  @doc """
  Extracts phone numbers and returns {phones, confidence} tuple.
  """
  def phones(text) do
    case Parsely.Phone.extract_all(text, "US") do
      [] -> {[], 0.0}
      list -> {Enum.take(list, 2), min(0.95, 0.6 + 0.15 * length(list))}
    end
  end

  # Helper functions for scoring-based extraction
  defp top_lines(text, n) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.take(n)
  end

  defp score_to_conf(score, max) do
    Float.round(min(1.0, score / max), 2)
  end

  defp score_name(line) do
    s = 0
    s = if Regex.match?(@name_mixed_case_pattern, line), do: s + 12, else: s
    s = if Regex.match?(@all_caps_short, line), do: s + 6, else: s
    s = if not String.contains?(String.downcase(line), "www"), do: s + 1, else: s
    s
  end

  defp score_position(line) do
    s = 0
    s = if Regex.match?(@position_pattern, line), do: s + 10, else: s
    s = if String.contains?(String.downcase(line), "engineer"), do: s + 5, else: s
    s = if String.contains?(String.downcase(line), "manager"), do: s + 5, else: s
    s = if String.contains?(String.downcase(line), "director"), do: s + 5, else: s
    s = if not String.contains?(String.downcase(line), "www"), do: s + 1, else: s
    s
  end

  defp score_company(line) do
    s = 0
    s = if Regex.match?(@company_pattern, line), do: s + 10, else: s
    s = if String.contains?(String.downcase(line), "inc"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "corp"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "llc"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "ltd"), do: s + 3, else: s
    s = if not String.contains?(String.downcase(line), "www"), do: s + 1, else: s
    s
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
  Extracts names and returns {name, confidence} tuple.
  """
  def name(text) do
    lines = top_lines(text, 10)

    candidates =
      lines
      |> Enum.map(&{score_name(&1), &1})
      |> Enum.filter(fn {s, _} -> s > 0 end)
      |> Enum.sort_by(fn {s, _} -> -s end)

    case candidates do
      [{score, line} | _] -> {line, score_to_conf(score, 20)}
      _ -> {nil, 0.0}
    end
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
  Extracts company names and returns {company, confidence} tuple.
  """
  def company(text) do
    lines = top_lines(text, 10)

    candidates =
      lines
      |> Enum.map(&{score_company(&1), &1})
      |> Enum.filter(fn {s, _} -> s > 0 end)
      |> Enum.sort_by(fn {s, _} -> -s end)

    case candidates do
      [{score, line} | _] -> {line, score_to_conf(score, 25)}
      _ -> {nil, 0.0}
    end
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
  Extracts positions and returns {position, confidence} tuple.
  """
  def position(text) do
    lines = top_lines(text, 10)

    candidates =
      lines
      |> Enum.map(&{score_position(&1), &1})
      |> Enum.filter(fn {s, _} -> s > 0 end)
      |> Enum.sort_by(fn {s, _} -> -s end)

    case candidates do
      [{score, line} | _] -> {line, score_to_conf(score, 25)}
      _ -> {nil, 0.0}
    end
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

  @doc """
  Extracts addresses and returns {address, confidence} tuple.
  """
  def address(text) do
    lines = top_lines(text, 15)

    # Try to find address components and join adjacent lines
    candidates = find_address_candidates(lines)

    case candidates do
      [] -> {nil, 0.0}
      [{score, address} | _] -> {address, score_to_conf(score, 30)}
    end
  end

  defp find_address_candidates(lines) do
    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, idx} ->
      score = score_address_line(line)
      if score > 0 do
        # Try to join with adjacent lines for better address
        joined = try_join_address_lines(lines, idx)
        [{score + score_address_line(joined), joined}]
      else
        []
      end
    end)
    |> Enum.sort_by(fn {score, _} -> -score end)
  end

  defp score_address_line(line) do
    s = 0
    s = if Regex.match?(@street_keywords, line), do: s + 10, else: s
    s = if Regex.match?(@address_zipcode, line), do: s + 8, else: s
    s = if Regex.match?(@address_city_state_zip, line), do: s + 6, else: s
    s = if String.contains?(String.downcase(line), "suite"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "apt"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "unit"), do: s + 3, else: s
    s = if String.contains?(String.downcase(line), "floor"), do: s + 2, else: s
    s = if not String.contains?(String.downcase(line), "www"), do: s + 1, else: s
    s
  end

  defp try_join_address_lines(lines, idx) do
    current_line = Enum.at(lines, idx, "")

    # Try to join with next line if it looks like address continuation
    next_line = Enum.at(lines, idx + 1, "")
    if is_address_continuation(next_line) do
      current_line <> " " <> next_line
    else
      current_line
    end
  end

  defp is_address_continuation(line) do
    String.length(line) > 0 and
    (Regex.match?(@address_zipcode, line) or
     Regex.match?(@address_city_state_zip, line) or
     String.contains?(String.downcase(line), "suite") or
     String.contains?(String.downcase(line), "apt") or
     String.contains?(String.downcase(line), "unit"))
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

  # Debug and test helpers (guarded by Mix.env())

  @doc """
  Test helper to extract all fields from sample text.
  Only available in development environment.
  """
  def test_with_sample_text(text \\ nil) do
    Mix.env() == :dev or raise "disabled in prod"

    sample_text = text || """
    John Doe
    Software Engineer
    Example Corp Inc
    john.doe@example.com
    +1 (555) 123-4567
    123 Main Street
    San Francisco, CA 94105
    """

    %{
      email: email(sample_text),
      phones: phones(sample_text),
      name: name(sample_text),
      company: company(sample_text),
      position: position(sample_text),
      address: address(sample_text)
    }
  end

  @doc """
  Debug helper to show scoring for each line.
  Only available in development environment.
  """
  def debug_line_scores(text) do
    Mix.env() == :dev or raise "disabled in prod"

    lines = top_lines(text, 10)

    lines
    |> Enum.map(fn line ->
      %{
        line: line,
        name_score: score_name(line),
        position_score: score_position(line),
        company_score: score_company(line),
        address_score: score_address_line(line)
      }
    end)
  end

  @doc """
  Debug helper to show confidence calculations.
  Only available in development environment.
  """
  def debug_confidence_calculation(score, max) do
    Mix.env() == :dev or raise "disabled in prod"

    %{
      score: score,
      max: max,
      confidence: score_to_conf(score, max),
      percentage: Float.round(score / max * 100, 1)
    }
  end
end
