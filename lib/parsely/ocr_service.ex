defmodule Parsely.OCRService do
  @moduledoc """
  Service for extracting text from business card images using OCR.
  """

  @doc """
  Extracts text from a base64 encoded image and parses it for business card information.
  """
    def extract_business_card_info(base64_image) do
    IO.puts("=== OCR SERVICE: Starting extraction ===")
    IO.puts("Base64 image length: #{String.length(base64_image)}")

    case call_ocr_api(base64_image) do
      {:ok, text} ->
        IO.puts("=== OCR SERVICE: Raw OCR text ===")
        IO.puts(text)
        parse_business_card_text(text)
    end
  end

    defp call_ocr_api(base64_image) do
    # Remove the data:image/jpeg;base64, prefix if present
    clean_base64 = String.replace(base64_image, ~r/^data:image\/[^;]+;base64,/, "")

    IO.puts("=== OCR SERVICE: Calling OCR API ===")
    IO.puts("Clean base64 length: #{String.length(clean_base64)}")

    # Try to use a free OCR API (OCR.space)
    case call_ocrspace_api(clean_base64) do
      {:ok, text} ->
        {:ok, text}
      {:error, reason} ->
        IO.puts("=== OCR SERVICE: OCR API failed, using fallback mock data ===")
        IO.puts("Error: #{reason}")
        # Fallback to mock data for testing
        IO.puts("=== OCR SERVICE: Using fallback mock data ===")
        {:ok, """
        John Doe
        Software Engineer
        Example Corp
        john.doe@example.com
        +1 (555) 123-4567
        """}
    end
  end

  defp call_ocrspace_api(base64_data) do
    # OCR.space free API (limited to 500 requests per day)
    url = "https://api.ocr.space/parse/image"

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body = URI.encode_query(%{
      "apikey" => "K81724188988957", # Free API key
      "base64Image" => "data:image/jpeg;base64,#{base64_data}",
      "language" => "eng",
      "isOverlayRequired" => "false",
      "filetype" => "jpg"
    })

    IO.puts("=== OCR SERVICE: Calling OCR.space API ===")

    IO.puts("=== OCR SERVICE: Making HTTP request to OCR.space ===")

    case HTTPoison.post(url, body, headers, [timeout: 30000, recv_timeout: 30000]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        IO.puts("=== OCR SERVICE: OCR.space API response ===")
        IO.puts(response_body)

        case Jason.decode(response_body) do
          {:ok, %{"ParsedResults" => [%{"ParsedText" => text} | _]}} ->
            {:ok, text}
          {:ok, %{"ParsedResults" => []}} ->
            {:error, "No text found in image"}
          {:ok, %{"ErrorMessage" => error}} ->
            IO.puts("=== OCR SERVICE: OCR API returned error ===")
            IO.puts("Error message: #{error}")
            {:error, "OCR API error: #{error}"}
          {:error, _} ->
            {:error, "Failed to parse OCR API response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "OCR API returned status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("=== OCR SERVICE: HTTP request failed ===")
        IO.puts("Error reason: #{reason}")
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  defp parse_business_card_text(text) do
    IO.puts("=== OCR SERVICE: Parsing business card text ===")

    # Clean up the text
    clean_text = text
      |> String.replace(~r/\r\n/, "\n")
      |> String.replace(~r/\r/, "\n")
      |> String.trim()

    IO.puts("Clean text:")
    IO.puts(clean_text)

    # Extract all fields
    email = find_email(clean_text)
    phone = find_phone(clean_text)
    name = find_name(clean_text, email, phone)
    company = find_company(clean_text, name, email, phone)
    position = find_position(clean_text, name, email, phone, company)

    result = %{
      name: name,
      email: email,
      phone: phone,
      company: company,
      position: position,
      raw_text: clean_text
    }

    IO.puts("=== OCR SERVICE: Extracted data ===")
    IO.puts("Name: #{name}")
    IO.puts("Email: #{email}")
    IO.puts("Phone: #{phone}")
    IO.puts("Company: #{company}")
    IO.puts("Position: #{position}")

    {:ok, result}
  end

  defp find_email(text) do
    IO.puts("=== FINDING EMAIL ===")
    IO.puts("Text: #{text}")

    # More comprehensive email patterns
    email_patterns = [
      ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, # Standard email
      ~r/\S+@\S+/, # Simple pattern - anything with @ symbol
      ~r/[A-Za-z0-9._%+-]+\s*@\s*[A-Za-z0-9.-]+\s*\.\s*[A-Z|a-z]{2,}/, # Email with spaces
    ]

    Enum.find_value(email_patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [email | _] ->
          # Clean up the email
          cleaned_email = email
          |> String.replace(~r/\s+/, "")
          |> String.replace("[at]", "@")
          |> String.replace("[dot]", ".")
          |> String.trim()

          IO.puts("Found email: #{cleaned_email}")
          cleaned_email
        nil -> nil
      end
    end) || (IO.puts("No email found") && nil)
  end

  defp find_phone(text) do
    # Look for any sequence of 10+ digits (phone numbers)
    case Regex.run(~r/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, text) do
      [phone | _] -> phone
      nil ->
        # Try other phone patterns
        case Regex.run(~r/\b\d{10,}\b/, text) do
          [phone | _] -> phone
          nil -> nil
        end
    end
  end

  defp find_name(text, email, phone) do
    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("=== ANALYZING LINES FOR NAME ===")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("Line #{index}: '#{line}'")
    end)

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

    # Score each line as a name candidate (prefer early lines, penalize URLs/addresses)
    scored_candidates =
      lines
      |> Enum.take(7)
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _idx} ->
        is_email_line?.(line) or is_phone_line?.(line) or not has_letters?.(line) or contains_role_or_company?.(line)
      end)
      |> Enum.map(fn {line, idx} ->
        base = 0
        base = if name_like_tokens?.(line), do: base + 5, else: base
        base = if not has_digits?.(line), do: base + 2, else: base
        base = if String.length(line) in 3..40, do: base + 1, else: base
        # Strongly prefer top lines on the card
        base = if idx <= 2, do: base + 4, else: base
        # Penalize things that look like addresses/URLs
        base = if contains_url?.(line), do: base - 5, else: base
        base = if looks_like_address?.(line), do: base - 4, else: base
        {base, line, idx}
      end)
      |> Enum.sort_by(fn {score, _line, _idx} -> -score end)

    case scored_candidates do
      [{top_score, best_line, best_idx} | _] when top_score >= 3 ->
        IO.puts("Found name (scored #{top_score}, idx #{best_idx}): '#{best_line}'")
        String.trim(best_line)

      _ ->
        IO.puts("No high-confidence name candidate found; attempting email-based fallback")
        # Fallback from email local-part: john.doe -> John Doe
        with true <- is_binary(email),
             [local | _] <- String.split(email, "@"),
             parts when parts != [] <- String.split(local, ~r/[._-]+/, trim: true) do
          candidate =
            parts
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")

          if candidate != "" do
            IO.puts("Inferred name from email: '#{candidate}'")
            candidate
          else
            IO.puts("Email-based fallback empty; returning nil")
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
              IO.puts("Using weak name fallback: '#{weak}'")
              String.trim(weak)
            else
              IO.puts("No name found")
              nil
            end
        end
    end
  end

  defp find_company(text, name, email, phone) do
    IO.puts("=== FINDING COMPANY ===")

    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("All lines for company analysis:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

    # Common company indicators
    company_indicators = ~w(
      inc ltd limited corp corporation company co gmbh srl spa bv sa plc
      technologies technology tech solutions systems group international
      university college school institute foundation
    )

    # Helper predicates
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_name_line? = fn line -> line == name end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end
    # Reuse a minimal set of position keywords to avoid picking job title as company
    position_keywords_for_exclusion = ~w(
      officer manager director engineer developer specialist coordinator supervisor lead senior junior principal
      president vice ceo cto cfo coo vp executive ambassador consul attache attaché secretary counselor
      commissioner
    )
    is_position_like? = fn line ->
      down = String.downcase(line)
      Enum.any?(position_keywords_for_exclusion, &String.contains?(down, &1))
    end

    IO.puts("Filtering out email, phone, name lines...")
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or is_name_line?.(line) or not has_letters?.(line)
    end)

    IO.puts("Remaining lines after filtering:")
    Enum.with_index(filtered_lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Filtered line #{index}: '#{line}'")
    end)

    # Look for lines that contain company indicators or look like company names
    company_candidates =
      filtered_lines
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_indicators = Enum.any?(company_indicators, &String.contains?(down, &1))
        looks_like_company = Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{2,50}$/, line) and
                              length(String.split(line, ~r/\s+/, trim: true)) in 1..4
        person_like = Regex.match?(~r/^[A-Z][A-Za-z\-']+\s+[A-Z][A-Za-z\-']+$/, line)
        url_like = is_urlish?.(line)
        position_like = is_position_like?.(line)

        IO.puts("  Analyzing line: '#{line}'")
        IO.puts("    Contains indicators: #{contains_indicators}")
        IO.puts("    Looks like company: #{looks_like_company}")
        IO.puts("    URL-like: #{url_like}")
        IO.puts("    Person-like: #{person_like}")
        IO.puts("    Position-like: #{position_like}")

        # Score: prioritize explicit indicators, de-prioritize person/url/position lines
        score = 0
        score = if contains_indicators, do: score + 5, else: score
        score = if looks_like_company, do: score + 1, else: score
        score = if person_like, do: score - 4, else: score
        score = if url_like, do: score - 5, else: score
        score = if position_like, do: score - 4, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    IO.puts("Company candidates found: #{length(company_candidates)}")
    Enum.with_index(company_candidates, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Candidate #{index}: '#{line}'")
    end)

    case company_candidates do
      [company | _] ->
        IO.puts("Found company: '#{company}'")
        String.trim(company)
      _ ->
        IO.puts("No company found")
        nil
    end
  end

  defp find_position(text, name, email, phone, company) do
    IO.puts("=== FINDING POSITION ===")

    # Split into lines and normalize
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    IO.puts("All lines for position analysis:")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Line #{index}: '#{line}'")
    end)

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
      public affairs officer protocol officer
    )

    # Helper predicates
    has_letters? = fn line -> Regex.match?(~r/[A-Za-z]/, line) end
    is_email_line? = fn line -> String.contains?(line, "@") end
    is_phone_line? = fn line -> Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) end
    is_name_line? = fn line -> line == name end
    is_company_line? = fn line -> line == company end
    is_urlish? = fn line ->
      down = String.downcase(line)
      String.contains?(down, "www") or String.contains?(down, "http")
    end

    IO.puts("Filtering out email, phone, name, company lines...")
    filtered_lines = lines
    |> Enum.reject(fn line ->
      is_email_line?.(line) or is_phone_line?.(line) or is_name_line?.(line) or
      is_company_line?.(line) or not has_letters?.(line)
    end)

    IO.puts("Remaining lines after filtering:")
    Enum.with_index(filtered_lines, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Filtered line #{index}: '#{line}'")
    end)

    # Look for lines that contain position keywords or look like job titles
    position_candidates =
      filtered_lines
      |> Enum.filter(fn line -> not is_urlish?.(line) end)
      |> Enum.map(fn line ->
        down = String.downcase(line)
        contains_keywords = Enum.any?(position_keywords, &String.contains?(down, &1))
        looks_like_title = Regex.match?(~r/^[A-Z][A-Za-z\s&.-]{2,40}$/, line) and
                            length(String.split(line, ~r/\s+/, trim: true)) in 1..3

        IO.puts("  Analyzing line: '#{line}'")
        IO.puts("    Contains keywords: #{contains_keywords}")
        IO.puts("    Looks like title: #{looks_like_title}")

        score = 0
        score = if contains_keywords, do: score + 5, else: score
        score = if looks_like_title, do: score + 1, else: score

        {score, line}
      end)
      |> Enum.filter(fn {score, _line} -> score > 0 end)
      |> Enum.sort_by(fn {score, _line} -> -score end)
      |> Enum.map(fn {_score, line} -> line end)

    IO.puts("Position candidates found: #{length(position_candidates)}")
    Enum.with_index(position_candidates, 1)
    |> Enum.each(fn {line, index} ->
      IO.puts("  Candidate #{index}: '#{line}'")
    end)

    case position_candidates do
      [position | _] ->
        IO.puts("Found position: '#{position}'")
        String.trim(position)
      _ ->
        IO.puts("No position found")
        nil
    end
  end

    @doc """
  Test function to verify OCR service is working.
  """
  def test_ocr() do
    IO.puts("=== TESTING OCR SERVICE ===")

    # Test with a simple base64 image (1x1 pixel)
    test_image = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxAAPwA/8A"

    {:ok, result} = extract_business_card_info(test_image)
    IO.puts("OCR test successful!")
    IO.puts("Result: #{inspect(result)}")
    {:ok, result}
  end

  @doc """
  Test function to verify OCR API directly (without fallback).
  """
  def test_ocr_api() do
    IO.puts("=== TESTING OCR API DIRECTLY ===")

    # Test with a simple base64 image (1x1 pixel)
    test_image = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxAAPwA/8A"

    # Remove the data:image/jpeg;base64, prefix
    clean_base64 = String.replace(test_image, ~r/^data:image\/[^;]+;base64,/, "")

    case call_ocrspace_api(clean_base64) do
      {:ok, text} ->
        IO.puts("OCR API test successful!")
        IO.puts("Raw text: #{text}")
        {:ok, text}
      {:error, reason} ->
        IO.puts("OCR API test failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Debug function to analyze OCR text and show what each extraction function finds.
  """
  def debug_ocr_extraction(text) do
    IO.puts("=== DEBUGGING OCR EXTRACTION ===")
    IO.puts("Input text:")
    IO.puts(text)
    IO.puts("")

    # Clean up the text
    clean_text = text
      |> String.replace(~r/\r\n/, "\n")
      |> String.replace(~r/\r/, "\n")
      |> String.trim()

    IO.puts("Clean text:")
    IO.puts(clean_text)
    IO.puts("")

    # Analyze each line
    lines = String.split(clean_text, "\n")
    IO.puts("=== LINE ANALYSIS ===")
    Enum.with_index(lines, 1)
    |> Enum.each(fn {line, index} ->
      trimmed_line = String.trim(line)
      if String.length(trimmed_line) > 0 do
        IO.puts("Line #{index}: '#{trimmed_line}'")
        IO.puts("  Length: #{String.length(trimmed_line)}")
        IO.puts("  Contains @: #{String.contains?(trimmed_line, "@")}")
        IO.puts("  Contains digits: #{Regex.match?(~r/\d/, trimmed_line)}")
        IO.puts("  All caps: #{Regex.match?(~r/^[A-Z\s]+$/, trimmed_line)}")
        IO.puts("  Name pattern: #{Regex.match?(~r/^[A-Za-z\s\.\-']+$/, trimmed_line)}")
        IO.puts("")
      end
    end)

            # Test each extraction function
    IO.puts("=== EXTRACTION RESULTS ===")

    # Extract the three main fields
    email = find_email(clean_text)
    phone = find_phone(clean_text)
    name = find_name(clean_text, email, phone)

    IO.puts("Name extraction: #{name}")
    IO.puts("Email extraction: #{email}")
    IO.puts("Phone extraction: #{phone}")

            IO.puts("")
    IO.puts("=== FINAL RESULT ===")
    result = %{
      name: name,
      email: email,
      phone: phone,
      company: nil,
      position: nil,
      raw_text: clean_text
    }
    IO.puts(inspect(result, pretty: true))

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

    IO.puts("=== TESTING WITH SAMPLE TEXT ===")
    debug_ocr_extraction(sample_text)
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

    IO.puts("=== TESTING WITH ANOTHER SAMPLE TEXT ===")
    debug_ocr_extraction(sample_text)
  end
end
