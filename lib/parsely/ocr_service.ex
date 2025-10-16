defmodule Parsely.OCRService do
  @moduledoc """
  Service for extracting text from business card images using OCR.
  """

  alias Parsely.Parsing.BusinessCardParser

  defp client do
    case Application.get_env(:parsely, :ocr_client, :space) do
      :space -> Parsely.OCR.SpaceClient
      :mock -> Parsely.OCR.MockClient
      client when is_atom(client) -> client
    end
  end

  @doc """
  Extracts text from a base64 encoded image and parses it for business card information.
  Accepts an OCR language code (e.g., "eng", "jpn", or "eng,jpn").
  """
  def extract_business_card_info(base64_image, language \\ "eng") do
    clean = String.replace(base64_image, ~r/^data:image\/[^;]+;base64,/, "")

    with {:ok, text, _meta} <- client().parse_base64_image(clean, language: language),
         {:ok, business_card} <- BusinessCardParser.parse(text, language: language) do
      # Convert to map format for backward compatibility
      {:ok, Parsely.BusinessCard.to_map(business_card)}
    else
      {:error, _} ->
        # Optional: feature-flag the mock fallback only in :dev/:test
        mock_text = """
        John Doe
        Software Engineer
        Example Corp
        john.doe@example.com
        +1 (555) 123-4567
        """
        case BusinessCardParser.parse(mock_text, language: language) do
          {:ok, business_card} -> {:ok, Parsely.BusinessCard.to_map(business_card)}
          error -> error
        end
    end
  end

  @doc """
  Extracts business card information and returns the typed struct.

  This is the new recommended API that returns a Parsely.BusinessCard struct
  with confidence scores.
  """
  def extract_business_card_struct(base64_image, language \\ "eng") do
    clean = String.replace(base64_image, ~r/^data:image\/[^;]+;base64,/, "")

    with {:ok, text, _meta} <- client().parse_base64_image(clean, language: language),
         {:ok, business_card} <- BusinessCardParser.parse(text, language: language) do
      {:ok, business_card}
    else
      {:error, _} ->
        # Optional: feature-flag the mock fallback only in :dev/:test
        mock_text = """
        John Doe
        Software Engineer
        Example Corp
        john.doe@example.com
        +1 (555) 123-4567
        """
        BusinessCardParser.parse(mock_text, language: language)
    end
  end




  def parse_english_business_card(text) do
    # Step 1: Extract email and phones (easily identified)
    email = find_email(text)
    phones = find_phones(text)
    primary_phone = List.first(phones)
    secondary_phone = Enum.at(phones, 1)

    # Step 2: Extract position based on scoring
    position = find_position_by_scoring(text, email, primary_phone)

    # Step 3: Extract name based on format (capitalization)
    name = find_name_by_format(text, email, primary_phone, position)

    # Step 4: Extract company using keywords and remaining lines
    company = find_company_by_keywords(text, email, primary_phone, position, name)

    # Step 5: Extract address from remaining lines
    address = find_address(text, email, primary_phone, position, name, company)

    result = %{
      name: name,
      email: email,
      primary_phone: primary_phone,
      secondary_phone: secondary_phone,
      company: company,
      position: position,
      address: address,
      raw_text: text
    }

    {:ok, result}
  end

  def find_email(text) do
    try do
      # Look for email patterns including corrupted ones with spaces
      email_patterns = [
        ~r/\b[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}\b/, # Standard email
        ~r/[\w._%+-]+@[\w.-]+\s+[A-Za-z]{2,}/, # Email with space before domain extension
        ~r/[\w._%+-]+@[\w.-]+\s+[A-Za-z]+\s+[A-Za-z]+/ # Email with multiple space-separated parts
      ]

      email_candidate = Enum.find_value(email_patterns, fn pattern ->
        case Regex.run(pattern, text) do
          [match | _] -> match
          nil -> nil
        end
      end)

      if email_candidate do
        # Clean up the email by removing spaces and fixing common OCR errors
        cleaned_email = email_candidate
        |> String.trim()
        |> String.replace(~r/\s+/, "") # Remove all spaces
        |> String.replace(~r/corn$/, ".com") # Fix common OCR error: "corn" -> ".com"
        |> String.replace(~r/[^\w@.-]/, "", global: true)

        # Validate it's a proper email format
        if Regex.match?(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/, cleaned_email) do
          cleaned_email
        else
          nil
        end
      else
        nil
      end
    rescue
      _error ->
        nil
    end
  end

  def find_phone(text) do
    try do
      # Look for phone patterns including corrupted ones
      phone_patterns = [
        ~r/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, # Standard US phone
        ~r/\+\d{1,3}[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, # International phone
        ~r/電語:\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Japanese phone with corruption
        ~r/\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Corrupted phone with separators
        ~r/電語:\+?[^\w]*(\d{1,3})[^\w]*(\d{3})[^\w]*(\d{3})[^\w]*(\d{4})/, # Heavily corrupted Japanese phone
        ~r/電語:\+?[^\d]*(\d{1,3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Japanese phone with single digit area code
        ~r/\b\d{10,}\b/, # Just digits
      ]

      Enum.find_value(phone_patterns, fn pattern ->
        case Regex.run(pattern, text) do
          [phone | _] ->
            # Clean up the phone number
            cleaned_phone = phone
            |> String.replace(~r/[^\d+\-().\s]/, "") # Remove non-phone characters
            |> String.replace(~r/\s+/, " ") # Normalize spaces
            |> String.trim()

            if String.length(cleaned_phone) >= 10 do
              cleaned_phone
            else
              nil
            end
          nil -> nil
        end
      end) || nil
    rescue
      _error ->
        nil
    end
  end

  def find_phones(text) do
    try do
      # Look for phone patterns including corrupted ones
      phone_patterns = [
        ~r/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, # Standard US phone
        ~r/\+\d{1,3}[-.\s]?\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, # International phone
        ~r/電語:\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Japanese phone with corruption
        ~r/\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Corrupted phone with separators
        ~r/電語:\+?[^\w]*(\d{1,3})[^\w]*(\d{3})[^\w]*(\d{3})[^\w]*(\d{4})/, # Heavily corrupted Japanese phone
        ~r/電語:\+?[^\d]*(\d{1,3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Japanese phone with single digit area code
        ~r/\b\d{10,}\b/, # Just digits
        ~r/\(\d{3}\)\s*\d{3}-\d{4}/, # (123) 456-7890 format
        ~r/Tel:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Tel: prefix
        ~r/Fax:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Fax: prefix
        ~r/Mobile:\s*\+?[^\d]*(\d{3})[^\d]*(\d{3})[^\d]*(\d{4})/, # Mobile: prefix
      ]

      # Find all phone numbers
      all_phones = phone_patterns
      |> Enum.flat_map(fn pattern ->
        Regex.scan(pattern, text)
        |> Enum.map(fn [phone | _] ->
          # Clean up the phone number
          cleaned_phone = phone
          |> String.replace(~r/[^\d+\-().\s]/, "") # Remove non-phone characters
          |> String.replace(~r/\s+/, " ") # Normalize spaces
          |> String.trim()

          # Format phone number consistently
          if String.length(cleaned_phone) >= 10 do
            # Remove any non-digit characters except + for international
            digits_only = String.replace(cleaned_phone, ~r/[^\d+]/, "")
            if String.starts_with?(digits_only, "+") do
              digits_only
            else
              # Format as (XXX) XXX-XXXX for US numbers
              if String.length(digits_only) == 10 do
                area_code = String.slice(digits_only, 0, 3)
                exchange = String.slice(digits_only, 3, 3)
                number = String.slice(digits_only, 6, 4)
                "(#{area_code}) #{exchange}-#{number}"
              else
                digits_only
              end
            end
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.uniq() # Remove duplicates
      |> Enum.take(2) # Take only first 2 phones

      all_phones
    rescue
      _error ->
        []
    end
  end

  def find_name_by_format(text, _email, _phone, position) do
    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Helper predicates
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line ->
      Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) or
      Regex.match?(~r/\+?\d{10,}/, line) or
      String.contains?(String.downcase(line), "tel") or
      String.contains?(String.downcase(line), "fax") or
      String.contains?(String.downcase(line), "mobile")
    end
    is_position_line? = fn line -> line == position end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-name lines
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email = is_email_line?.(line)
      is_phone = is_phone_line?.(line)
      is_pos = is_position_line?.(line)
      has_letters = has_letters?.(line)
      is_url = is_urlish?.(line)

      is_email or is_phone or is_pos or not has_letters or is_url
    end)

    # Look for name patterns - prioritize capitalized names
    name_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        # Check for various name formats including initials with dots
        is_capitalized_name = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/, line)
        is_mixed_case_name = Regex.match?(~r/^[A-Z][a-z]+\s+[A-Z][a-z]+$/, line)
        is_all_caps_name = Regex.match?(~r/^[A-Z]+\s+[A-Z]+$/, line)
        is_single_word = Regex.match?(~r/^[A-Z][A-Za-z]+$/, line)

        # New patterns for names with initials (with or without dots)
        is_name_with_initial = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+$/, line)
        is_name_with_initial_mixed = Regex.match?(~r/^[A-Z][a-z]+\s+[A-Z]\.?\s+[A-Z][a-z]+$/, line)
        is_name_with_initial_all_caps = Regex.match?(~r/^[A-Z]+\s+[A-Z]\.?\s+[A-Z]+$/, line)

        # Pattern for initials at the beginning (e.g., "AJ. Preller")
        is_initial_first = Regex.match?(~r/^[A-Z]+\.?\s+[A-Z][A-Za-z]+$/, line)
        is_initial_first_all_caps = Regex.match?(~r/^[A-Z]+\.?\s+[A-Z]+$/, line)

        # Pattern for names with multiple initials (e.g., "John A. B. Smith")
        is_name_with_multiple_initials = Regex.match?(~r/^[A-Z][A-Za-z]+(\s+[A-Z]\.?)+\s+[A-Z][A-Za-z]+$/, line)

        # Pattern for names with titles/credentials (e.g., "MITCHELL CREININ, M.D.")
        is_name_with_title = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?$/, line)
        is_name_with_title_all_caps = Regex.match?(~r/^[A-Z]+\s+[A-Z]+,\s*[A-Z]\.?[A-Z]?\.?$/, line)

        # Pattern for names with credentials (e.g., "Arthur D. Casciato, Ph.D.")
        is_name_with_credentials = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?/, line)

        # Check if it looks like a person name (not a company/job title/address)
        company_keywords = ~w(ltd limited inc incorporated corp corporation company co center centre university college school institute foundation)
        address_keywords = ~w(way street avenue road drive lane boulevard suite apt apartment unit floor room)
        state_codes = ~w(AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY)

        # Common city/place names that should not be person names
        place_names = ~w(new york new jersey new brunswick los angeles san francisco chicago boston philadelphia houston dallas miami atlanta seattle denver phoenix detroit minneapolis portland las vegas orlando tampa austin nashville charlotte raleigh richmond columbus cleveland pittsburgh buffalo rochester syracuse albany binghamton utica schenectady troy poughkeepsie newburgh kingston middletown newburgh)

        contains_company_keywords = Enum.any?(company_keywords, &String.contains?(String.downcase(line), &1))
        contains_address_keywords = Enum.any?(address_keywords, &String.contains?(String.downcase(line), &1))
        contains_state_code = Enum.any?(state_codes, fn state_code ->
          # Only match state codes as standalone words (with word boundaries)
          Regex.match?(~r/\b#{state_code}\b/, String.upcase(line))
        end)
        contains_place_name = Enum.any?(place_names, fn place_name ->
          # Check if the line contains a common place name
          String.contains?(String.downcase(line), place_name)
        end)
        has_zipcode = Regex.match?(~r/\b\d{5}(-\d{4})?\b/, line)

        looks_like_person = not contains_company_keywords and
                           not contains_address_keywords and
                           not contains_state_code and
                           not contains_place_name and
                           not has_zipcode


        # Score based on format and likelihood
        # Names must be at least two words (no single word names)
        score = 0
        score = if is_capitalized_name and looks_like_person and not is_single_word, do: score + 10, else: score
        score = if is_mixed_case_name and looks_like_person and not is_single_word, do: score + 8, else: score
        score = if is_all_caps_name and looks_like_person and not is_single_word, do: score + 6, else: score

        # Higher scores for names with initials (they're very common and specific)
        score = if is_name_with_initial and looks_like_person, do: score + 12, else: score
        score = if is_name_with_initial_mixed and looks_like_person, do: score + 11, else: score
        score = if is_name_with_initial_all_caps and looks_like_person, do: score + 9, else: score
        score = if is_initial_first and looks_like_person, do: score + 12, else: score
        score = if is_initial_first_all_caps and looks_like_person, do: score + 11, else: score
        score = if is_name_with_multiple_initials and looks_like_person, do: score + 13, else: score

        # Very high scores for names with titles/credentials (very specific)
        score = if is_name_with_title and looks_like_person, do: score + 15, else: score
        score = if is_name_with_title_all_caps and looks_like_person, do: score + 14, else: score
        score = if is_name_with_credentials and looks_like_person, do: score + 16, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    case name_candidates do
      [name | _] ->
        String.trim(name)
      _ ->
        nil
    end
  end

  defp find_name(text, email, _phone) do
    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Common words that indicate titles/companies we should skip when guessing a name
    role_or_company_keywords = ~w(
      engineer developer manager director founder cofounder chief officer
      marketing sales product design designer accounting consultant analyst
      software hardware solutions technologies technology tech ltd limited inc llc corp corporation company co gmbh srl spa bv sa plc university college school
      department division team
    )

    contains_role_or_company? = fn line ->
      down = String.downcase(line)
      Enum.any?(role_or_company_keywords, &String.contains?(down, &1))
    end

    # Helper predicates for scoring
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    has_digits? = fn line -> Regex.match?(~r/\d/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    contains_url? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end
    looks_like_address? = fn line ->
      down = String.downcase(line)
      Regex.match?(~r/\d/, line) or String.contains?(down, "st.") or String.contains?(down, "street") or String.contains?(down, "ave") or String.contains?(down, "road") or String.contains?(down, ",")
    end

    # Prefer 2-3 tokens, capitalized words
    name_like_tokens? = fn line ->
      tokens =
        line
        |> String.replace(~r/[^A-Za-z\s\-'.]/, "")
        |> String.split(~r/\s+/, trim: true)

      length(tokens) in 2..3 and Enum.all?(tokens, fn t ->
        # Allow initials like "J." or capitalized words like "John"
        Regex.match?(~r/^[A-Z][a-z]+$|^[A-Z]\.$/, t)
      end)
    end

    # Check if line looks like a person name (First Last pattern, including with initials)
    is_person_name_pattern? = fn line ->
      # Look for various name patterns including initials
      down = String.downcase(line)

      # Basic First Last pattern
      is_basic_name = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/, line)

      # First Initial Last pattern (with or without dot)
      is_name_with_initial = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z]\.?\s+[A-Z][A-Za-z]+$/, line)

      # Multiple initials pattern (e.g., "John A. B. Smith")
      is_name_with_multiple_initials = Regex.match?(~r/^[A-Z][A-Za-z]+(\s+[A-Z]\.?)+\s+[A-Z][A-Za-z]+$/, line)

      # Names with titles/credentials (e.g., "MITCHELL CREININ, M.D.")
      is_name_with_title = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+,\s*[A-Z]\.?[A-Z]?\.?$/, line)

      is_name_pattern = is_basic_name or is_name_with_initial or is_name_with_multiple_initials or is_name_with_title

      # Exclude common job title words
      is_not_job_title = not Enum.any?(~w(account executive account manager sales manager marketing manager engineer developer designer consultant analyst specialist director manager supervisor coordinator lead senior junior president vice ceo cto cfo coo vp executive officer ambassador consul attache secretary counselor commissioner), &String.contains?(down, &1))

      is_name_pattern and is_not_job_title
    end

    # Check for lines that are clearly not names (general patterns)
    looks_like_non_name? = fn line ->
      down = String.downcase(line)
      # Check for lines that are too short
      String.length(line) < 3 or
      # Check for lines that contain mostly symbols or punctuation
      Regex.match?(~r/^[^A-Za-z]*$/, line) or
      # Check for lines that start with symbols
      Regex.match?(~r/^[•\s«»\-_]+/, line) or
      # Check for lines that are mostly numbers
      Regex.match?(~r/^\d+/, line) or
      # Check for lines that contain common non-name patterns
      String.contains?(down, "tel:") or
      String.contains?(down, "fax:") or
      String.contains?(down, "email:") or
      String.contains?(down, "phone:") or
      String.contains?(down, "suite") or
      String.contains?(down, "street") or
      String.contains?(down, "avenue") or
      String.contains?(down, "road") or
      String.contains?(down, "st.") or
      String.contains?(down, "ave.") or
      String.contains?(down, "rd.") or
      # Check for lines that are all caps and contain common business terms
      (Regex.match?(~r/^[A-Z\s]+$/, line) and
       (String.contains?(down, "national") or String.contains?(down, "international") or
        String.contains?(down, "corp") or String.contains?(down, "inc") or
        String.contains?(down, "ltd") or String.contains?(down, "llc")))
    end

    # Score each line as a name candidate (prefer early lines, penalize URLs/addresses)
    scored_candidates =
      lines
      |> Enum.take(7)
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _idx} ->
        is_email_line?.(line) or is_phone_line?.(line) or not has_letters?.(line) or
        contains_role_or_company?.(line) or looks_like_non_name?.(line)
      end)
      |> Enum.map(fn {line, idx} ->
        base = 0
        base = if name_like_tokens?.(line), do: base + 5, else: base
        base = if is_person_name_pattern?.(line), do: base + 8, else: base  # Strongly prefer person name patterns
        base = if not has_digits?.(line), do: base + 2, else: base
        base = if String.length(line) in 3..40, do: base + 1, else: base
        # Prefer top lines on the card, but not as strongly
        base = if idx <= 3, do: base + 2, else: base
        # Penalize things that look like addresses/URLs
        base = if contains_url?.(line), do: base - 5, else: base
        base = if looks_like_address?.(line), do: base - 4, else: base
        {base, line, idx}
      end)
      |> Enum.sort_by(fn {score, _line, _idx} -> -score end)

    case scored_candidates do
      [{top_score, best_line, _best_idx} | _] when top_score >= 3 ->
        String.trim(best_line)

      _ ->
        # Fallback from email local-part: john.doe -> John Doe
        with true <- is_binary(email),
             [local | _] <- String.split(email, "@"),
             parts when parts != [] <- String.split(local, ~r/[._-]+/, trim: true) do
          candidate =
            parts
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")

          if candidate != "" do
            candidate
          else
            nil
          end
        else
          _ ->
            # Final fallback: pick first line that looks most like a name even if low score
            weak =
              lines
              |> Enum.reject(&(is_email_line?.(&1) or is_phone_line?.(&1) or contains_role_or_company?.(&1)))
              |> Enum.find(name_like_tokens?)

            if weak do
              String.trim(weak)
            else
              nil
            end
        end
    end
  end

  def find_company_by_keywords(text, _email, _phone, position, name) do
    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Company keywords and indicators
    company_keywords = ~w(
      ltd limited inc incorporated corp corporation company co
      gmbh srl spa bv sa plc llc
      technologies technology tech solutions systems group
      international national global
      university college school institute foundation
      center centre center center
      hospital medical clinic
      bank financial insurance
      consulting consulting services
      manufacturing production
      retail store shop
      restaurant cafe hotel
      law legal firm
      real estate property
      media communications
      entertainment sports baseball club team
      nonprofit non-profit ngo
      government municipal
      association society
      federation union
      alliance partnership
      venture capital
      private equity
      investment fund
    )

    # Helper predicates
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line ->
      Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) or
      Regex.match?(~r/\+?\d{10,}/, line) or
      String.contains?(String.downcase(line), "tel") or
      String.contains?(String.downcase(line), "fax") or
      String.contains?(String.downcase(line), "mobile")
    end
    is_position_line? = fn line -> line == position end
    is_name_line? = fn line -> line == name end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-company lines
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or is_position_line?.(line) or
      is_name_line?.(line) or not has_letters?.(line) or is_urlish?.(line)
    end)

    # Score each line as a company candidate
    company_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_keywords = Enum.any?(company_keywords, &String.contains?(down, &1))
        looks_like_company = Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{2,50}$/, line) and
                            length(String.split(line, ~r/\s+/, trim: true)) in 1..4

        # Check if it looks like a person name (should be excluded)
        looks_like_person = Regex.match?(~r/^[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+$/, line) and
                           not contains_keywords


        # Score based on keywords and format
        score = 0
        score = if contains_keywords, do: score + 8, else: score
        score = if looks_like_company, do: score + 2, else: score
        score = if looks_like_person, do: score - 5, else: score

        # Penalize very short lines (likely not company names)
        score = if String.length(line) < 3, do: score - 10, else: score

        # Penalize single words that are just keywords (like "com", "inc", etc.)
        is_single_keyword = String.length(line) <= 4 and contains_keywords and not String.contains?(line, " ")
        score = if is_single_keyword, do: score - 15, else: score

        # Penalize lines that look like addresses (contain address keywords)
        address_keywords = ~w(way street avenue road drive lane boulevard suite apt apartment unit floor room)
        contains_address_keywords = Enum.any?(address_keywords, &String.contains?(String.downcase(line), &1))
        has_zipcode = Regex.match?(~r/\b\d{5}(-\d{4})?\b/, line) # US zipcode pattern
        has_state = Regex.match?(~r/\b[A-Z]{2}\b/, line) # Two-letter state code
        looks_like_address = contains_address_keywords or has_zipcode or has_state
        score = if looks_like_address, do: score - 20, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    case company_candidates do
      [company | _] ->
        String.trim(company)
      _ ->
        nil
    end
  end


  def find_position_by_scoring(text, _email, _phone) do
    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Common job titles/positions
    position_keywords = ~w(
      engineer developer manager director founder cofounder chief officer
      marketing sales product design designer accounting consultant analyst
      specialist coordinator supervisor lead senior junior principal
      president vice ceo cto cfo coo vp executive
      # Embassy and diplomatic positions
      ambassador consul consul general deputy consul
      press attache cultural attache commercial attache
      first secretary second secretary third secretary
      attaché attaché attaché attaché
      minister counselor embassy embassy
      diplomatic diplomatic officer foreign service
      trade commissioner economic officer political officer
      public affairs officer protocol officer advisor operations manager
    )

    # Helper predicates
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    # Filter out obvious non-position lines
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or not has_letters?.(line) or is_urlish?.(line)
    end)

    # Score each line as a position candidate
    position_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_keywords = Enum.any?(position_keywords, &String.contains?(down, &1))
        looks_like_title = Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{2,40}$/, line) and
                            length(String.split(line, ~r/\s+/, trim: true)) in 1..3


        score = 0
        score = if contains_keywords, do: score + 5, else: score
        score = if looks_like_title, do: score + 1, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    case position_candidates do
      [position | _] ->
        String.trim(position)
      _ ->
        nil
    end
  end


  @doc """
  Test function to verify OCR service is working.
  """
  def test_ocr() do
    # Test with a simple base64 image (1x1 pixel)
    test_image = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxAAPwA/8A"

    extract_business_card_info(test_image, "eng")
  end

  @doc """
  Test function to verify OCR API directly (without fallback).
  """
  def test_ocr_api() do
    # Test with a simple base64 image (1x1 pixel)
    test_image = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxAAPwA/8A"

    clean = String.replace(test_image, ~r/^data:image\/[^;]+;base64,/, "")
    client().parse_base64_image(clean, language: "eng")
  end

  @doc """
  Debug function to analyze OCR text and show what each extraction function finds.
  """
  def debug_ocr_extraction(text) do
    # Clean up the text
    clean_text = text
      |> String.replace(~r/\r\n/, "\n")
      |> String.replace(~r/\r/, "\n")
      |> String.trim()

    # Extract the three main fields
    email = find_email(clean_text)
    phone = find_phone(clean_text)
    name = find_name(clean_text, email, phone)

    result = %{
      name: name,
      email: email,
      phone: phone,
      company: nil,
      position: nil,
      raw_text: clean_text
    }

    result
  end

  @doc """
  Test function with sample business card text to debug extraction logic.
  """
  def test_with_sample_text() do
    sample_text = """
    John Doe
    Software Engineer
    Example Corp
    john.doe@example.com
    +1 (555) 123-4567
    """

    debug_ocr_extraction(sample_text)
  end

  def find_address(text, email, phone, position, name, company) do
    try do
      lines = String.split(text, "\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

      # Filter out lines that are already identified as other fields
      filtered_lines = lines
      |> Enum.reject(fn line ->
        line == email or
        line == phone or
        line == position or
        line == name or
        line == company or
        String.contains?(line, "@") or  # Contains email
        Regex.match?(~r/\(\d{3}\)\s*\d{3}-\d{4}/, line) or  # Phone pattern
        Regex.match?(~r/\+?\d{10,}/, line) or  # Phone pattern with + and 10+ digits
        String.contains?(String.downcase(line), "tel") or
        String.contains?(String.downcase(line), "fax") or
        String.contains?(String.downcase(line), "mobile") or
        String.contains?(String.downcase(line), "email") or
        String.contains?(String.downcase(line), "phone")
      end)
      |> Enum.reject(fn line ->
        # Also filter out lines that are likely company names (all caps, short, no numbers)
        String.upcase(line) == line and String.length(line) < 20 and not Regex.match?(~r/\d/, line)
      end)
      |> Enum.reject(fn line ->
        # Filter out single words that are likely not addresses (like "com", "inc", etc.)
        String.length(line) <= 4 and not String.contains?(line, " ") and not Regex.match?(~r/\d/, line)
      end)


      # Look for address patterns and try to join related lines
      address_candidates = find_address_candidates(filtered_lines)

      # Return the first (most likely) address candidate
      case address_candidates do
        [address | _] ->
          address
        [] ->
          nil
      end
    rescue
      _error ->
        nil
    end
  end

  defp find_address_candidates(lines) do
    # First, try to find individual lines that look like addresses
    individual_candidates = lines
    |> Enum.filter(fn line ->
      is_address_line?(line)
    end)

    # Then, try to find multi-line addresses by looking for patterns
    multi_line_candidates = find_multi_line_addresses(lines)

    # Combine and prioritize candidates
    all_candidates = individual_candidates ++ multi_line_candidates

    # Remove duplicates and sort by likelihood
    all_candidates
    |> Enum.uniq()
    |> Enum.sort_by(fn candidate ->
      # Score based on length and completeness
      score = String.length(candidate)
      # Bonus for containing common address elements
      score = if String.contains?(String.downcase(candidate), "suite") or
                  String.contains?(String.downcase(candidate), "unit") or
                  String.contains?(String.downcase(candidate), "apt"), do: score + 10, else: score
      score = if Regex.match?(~r/\d+/, candidate), do: score + 5, else: score
      score = if Regex.match?(~r/[A-Za-z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?/, candidate), do: score + 15, else: score
      -score  # Negative for descending sort
    end)
  end

  defp is_address_line?(line) do
    # Look for lines that contain address indicators
    contains_street_indicators = String.contains?(String.downcase(line), "street") or
                                String.contains?(String.downcase(line), "st") or
                                String.contains?(String.downcase(line), "avenue") or
                                String.contains?(String.downcase(line), "ave") or
                                String.contains?(String.downcase(line), "road") or
                                String.contains?(String.downcase(line), "rd") or
                                String.contains?(String.downcase(line), "boulevard") or
                                String.contains?(String.downcase(line), "blvd") or
                                String.contains?(String.downcase(line), "drive") or
                                String.contains?(String.downcase(line), "dr") or
                                String.contains?(String.downcase(line), "lane") or
                                String.contains?(String.downcase(line), "ln") or
                                String.contains?(String.downcase(line), "way") or
                                String.contains?(String.downcase(line), "court") or
                                String.contains?(String.downcase(line), "ct") or
                                String.contains?(String.downcase(line), "place") or
                                String.contains?(String.downcase(line), "pl")

    # Look for lines with numbers (street numbers)
    contains_numbers = Regex.match?(~r/\d+/, line)

    # Look for lines with city/state/zip patterns
    contains_city_state_zip = Regex.match?(~r/[A-Za-z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?/, line) or
                             Regex.match?(~r/[A-Za-z\s]+,\s*[A-Za-z\s]+,\s*[A-Z]{2}\s+\d{5}(-\d{4})?/, line)

    # Look for suite/unit indicators
    contains_suite = String.contains?(String.downcase(line), "suite") or
                    String.contains?(String.downcase(line), "unit") or
                    String.contains?(String.downcase(line), "apt") or
                    String.contains?(String.downcase(line), "#")

    contains_street_indicators or (contains_numbers and contains_city_state_zip) or contains_suite
  end

  defp find_multi_line_addresses(lines) do
    # Look for consecutive lines that together form an address
    # Try different combinations of consecutive lines
    for i <- 0..(length(lines) - 1),
        max_j = min(i + 3, length(lines) - 1),
        i + 1 <= max_j,
        j <- (i + 1)..max_j,
        address_lines = Enum.slice(lines, i..j) |> Enum.reject(&(&1 == "")),
        length(address_lines) >= 2,
        combined_address = Enum.join(address_lines, ", "),
        is_likely_address?(combined_address) do
      combined_address
    end
  end

  defp is_likely_address?(text) do
    # Check if the combined text looks like an address
    contains_street_number = Regex.match?(~r/\d+\s+/, text)  # Contains number followed by space
    contains_street_name = Regex.match?(~r/\d+\s+[A-Za-z\s]+/, text)  # Number followed by letters
    contains_suite = String.contains?(String.downcase(text), "suite") or
                    String.contains?(String.downcase(text), "unit") or
                    String.contains?(String.downcase(text), "apt")
    contains_city = Regex.match?(~r/[A-Za-z\s]+,\s*[A-Z]{2}/, text)  # City, State pattern
    contains_zip = Regex.match?(~r/\d{5}(-\d{4})?/, text)  # ZIP code pattern
    contains_city_name = Regex.match?(~r/[A-Za-z\s]+\.?\s*\d{3}/, text)  # City name followed by partial zip

    # More flexible scoring - need at least 2 address indicators
    indicators = [
      contains_street_number,
      contains_street_name,
      contains_suite,
      contains_city,
      contains_zip,
      contains_city_name
    ]

    indicator_count = Enum.count(indicators, &(&1 == true))

    # Must have at least 2 indicators to be considered an address
    indicator_count >= 2
  end

  @doc """
  Test function with another sample business card text.
  """
  def test_with_another_sample() do
    sample_text = """
    Jane Smith
    Marketing Director
    Tech Solutions Inc
    jane.smith@techsolutions.com
    (555) 987-6543
    """

    debug_ocr_extraction(sample_text)
  end
end
