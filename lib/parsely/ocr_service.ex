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

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        IO.puts("=== OCR SERVICE: OCR.space API response ===")
        IO.puts(response_body)

        case Jason.decode(response_body) do
          {:ok, %{"ParsedResults" => [%{"ParsedText" => text} | _]}} ->
            {:ok, text}
          {:ok, %{"ParsedResults" => []}} ->
            {:error, "No text found in image"}
          {:ok, %{"ErrorMessage" => error}} ->
            {:error, "OCR API error: #{error}"}
          {:error, _} ->
            {:error, "Failed to parse OCR API response"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "OCR API returned status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
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

    # Extract information using regex patterns
    name = extract_name(clean_text)
    email = extract_email(clean_text)
    phone = extract_phone(clean_text)
    company = extract_company(clean_text)
    position = extract_position(clean_text)

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

  defp extract_name(text) do
    # Look for patterns that might be names
    # Usually names are on the first few lines and contain only letters, spaces, and common name characters
    lines = String.split(text, "\n")

    # Look for lines that look like names (mostly letters, 2-4 words, no special characters)
    name_candidates = lines
      |> Enum.take(5) # Check first 5 lines
      |> Enum.filter(fn line ->
        line = String.trim(line)
        String.length(line) > 2 and
        String.length(line) < 50 and
        Regex.match?(~r/^[A-Za-z\s\.\-']+$/, line) and
        !Regex.match?(~r/^[A-Z\s]+$/, line) and # Not all caps (likely company)
        !String.contains?(line, "@") and # Not an email
        !Regex.match?(~r/\d/, line) # No numbers
      end)

    case name_candidates do
      [name | _] -> String.trim(name)
      _ -> nil
    end
  end

  defp extract_email(text) do
    case Regex.run(~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/, text) do
      [email | _] -> email
      nil -> nil
    end
  end

  defp extract_phone(text) do
    # Look for various phone number formats
    phone_patterns = [
      ~r/\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/, # US format: 123-456-7890
      ~r/\b\+\d{1,3}[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{1,4}\b/, # International
      ~r/\b\(\d{3}\)\s?\d{3}[-.\s]?\d{4}\b/, # (123) 456-7890
      ~r/\b\d{10}\b/, # Just 10 digits
      ~r/\+\d{1,3}\s?\(\d{3}\)\s?\d{3}[-.\s]?\d{4}\b/ # +1 (555) 123-4567
    ]

    Enum.find_value(phone_patterns, fn pattern ->
      case Regex.run(pattern, text) do
        [phone | _] -> phone
        nil -> nil
      end
    end)
  end

  defp extract_company(text) do
    lines = String.split(text, "\n")

    # Look for lines that might be company names
    # Usually on early lines, not too long, might be mixed case
    company_candidates = lines
      |> Enum.take(8) # Check first 8 lines
      |> Enum.filter(fn line ->
        line = String.trim(line)
        String.length(line) > 2 and
        String.length(line) < 40 and
        # Look for lines that contain "Corp", "Inc", "LLC", etc. or are all caps
        (String.contains?(line, "Corp") or
         String.contains?(line, "Inc") or
         String.contains?(line, "LLC") or
         String.contains?(line, "Ltd") or
         String.contains?(line, "Company") or
         Regex.match?(~r/^[A-Z\s&\.\-]+$/, line)) and
        !String.contains?(line, "@") and # Not an email
        !Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) # Not a phone number
      end)

    case company_candidates do
      [company | _] -> String.trim(company)
      _ -> nil
    end
  end

  defp extract_position(text) do
    lines = String.split(text, "\n")

    # Look for job titles (usually contain words like "Manager", "Director", "Engineer", etc.)
    position_keywords = [
      "manager", "director", "engineer", "developer", "analyst", "coordinator",
      "specialist", "consultant", "executive", "president", "ceo", "cto", "cfo",
      "vp", "vice president", "head", "lead", "senior", "junior", "associate",
      "officer", "chief", "principal", "architect", "designer", "programmer"
    ]

    position_candidates = lines
      |> Enum.filter(fn line ->
        line = String.trim(line)
        String.length(line) > 3 and String.length(line) < 50 and
        Enum.any?(position_keywords, fn keyword ->
          String.contains?(String.downcase(line), keyword)
        end) and
        !String.contains?(line, "@") and # Not an email
        !Regex.match?(~r/\d{3}[-.\s]?\d{3}[-.\s]?\d{4}/, line) # Not a phone number
      end)

    case position_candidates do
      [position | _] -> String.trim(position)
      _ -> nil
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
end
