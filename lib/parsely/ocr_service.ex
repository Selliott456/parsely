defmodule Parsely.OCRService do
  @moduledoc """
  Service for extracting text from business card images using OCR.
  """

  @doc """
  Extracts text from a base64 encoded image and parses it for business card information.
  """
  def extract_business_card_info(base64_image) do
    case call_ocr_api(base64_image) do
      {:ok, text} ->
        parse_business_card_text(text)
    end
  end

      defp call_ocr_api(_base64_image) do
    # For now, we'll simulate OCR results since HTTPoison isn't loading properly
    # In production, you would use a real OCR service like Google Vision API or AWS Textract

    # Simulate processing delay
    :timer.sleep(1000)

    # Return simulated OCR results
    {:ok, """
    John Doe
    Software Engineer
    Example Corp
    john.doe@example.com
    +1 (555) 123-4567
    """}
  end

  defp parse_business_card_text(text) do
    # Clean up the text
    clean_text = text
      |> String.replace(~r/\r\n/, "\n")
      |> String.replace(~r/\r/, "\n")
      |> String.trim()

    # Extract information using regex patterns
    name = extract_name(clean_text)
    email = extract_email(clean_text)
    phone = extract_phone(clean_text)
    company = extract_company(clean_text)
    position = extract_position(clean_text)

    {:ok, %{
      name: name,
      email: email,
      phone: phone,
      company: company,
      position: position,
      raw_text: clean_text
    }}
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
        !Regex.match?(~r/^[A-Z\s]+$/, line) # Not all caps (likely company)
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
      ~r/\b\d{10}\b/ # Just 10 digits
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
    # Usually all caps, on early lines, not too long
    company_candidates = lines
      |> Enum.take(8) # Check first 8 lines
      |> Enum.filter(fn line ->
        line = String.trim(line)
        String.length(line) > 2 and
        String.length(line) < 40 and
        Regex.match?(~r/^[A-Z\s&\.\-]+$/, line) and # All caps with some special chars
        !Regex.match?(~r/^[A-Z\s]+$/, line) # Not just letters and spaces
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
      "vp", "vice president", "head", "lead", "senior", "junior", "associate"
    ]

    position_candidates = lines
      |> Enum.filter(fn line ->
        line = String.trim(line)
        String.length(line) > 3 and String.length(line) < 50 and
        Enum.any?(position_keywords, fn keyword ->
          String.contains?(String.downcase(line), keyword)
        end)
      end)

    case position_candidates do
      [position | _] -> String.trim(position)
      _ -> nil
    end
  end
end
