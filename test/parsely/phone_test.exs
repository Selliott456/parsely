defmodule Parsely.PhoneTest do
  use ExUnit.Case, async: true

  alias Parsely.Phone

  describe "extract_all/2" do
    test "extracts US phone numbers" do
      text = "Call us at (555) 123-4567 or 555-987-6543"
      phones = Phone.extract_all(text)

      assert length(phones) >= 1
      assert Enum.any?(phones, &String.contains?(&1, "+1"))
    end

    test "extracts international phone numbers" do
      text = "International: +44 20 7946 0958"
      phones = Phone.extract_all(text)

      assert length(phones) >= 1
      assert Enum.any?(phones, &String.contains?(&1, "+44"))
    end

    test "handles multiple phone numbers" do
      text = "Office: (555) 123-4567, Mobile: +1 555 987 6543"
      phones = Phone.extract_all(text)

      assert length(phones) >= 2
    end

    test "returns empty list for no valid phone numbers" do
      text = "No phone numbers here"
      phones = Phone.extract_all(text)

      assert phones == []
    end

    test "works with different default regions" do
      text = "020 7946 0958"  # UK number without country code
      phones_us = Phone.extract_all(text, "US")
      phones_uk = Phone.extract_all(text, "GB")

      # Should work better with UK region
      assert length(phones_uk) >= length(phones_us)
    end
  end

  describe "extract_primary_and_secondary/2" do
    test "returns primary and secondary phone numbers" do
      text = "Office: (555) 123-4567, Mobile: +1 555 987 6543"
      {primary, secondary} = Phone.extract_primary_and_secondary(text)

      assert is_binary(primary)
      assert is_binary(secondary)
      assert primary != secondary
    end

    test "returns only primary when one phone number" do
      text = "Call us at (555) 123-4567"
      {primary, secondary} = Phone.extract_primary_and_secondary(text)

      assert is_binary(primary)
      assert secondary == nil
    end

    test "returns nil for both when no phone numbers" do
      text = "No phone numbers here"
      {primary, secondary} = Phone.extract_primary_and_secondary(text)

      assert primary == nil
      assert secondary == nil
    end

    test "limits to at most 2 phone numbers" do
      text = "Phone 1: (555) 111-1111, Phone 2: (555) 222-2222, Phone 3: (555) 333-3333"
      {primary, secondary} = Phone.extract_primary_and_secondary(text)

      assert is_binary(primary)
      assert is_binary(secondary)
      # Should not include the third phone number
    end
  end

  describe "valid?/2" do
    test "validates US phone numbers" do
      assert Phone.valid?("(555) 123-4567")
      assert Phone.valid?("+1 555 123 4567")
      assert Phone.valid?("555-123-4567")
    end

    test "validates international phone numbers" do
      assert Phone.valid?("+44 20 7946 0958")
      assert Phone.valid?("+81 3 1234 5678")
    end

    test "rejects invalid phone numbers" do
      refute Phone.valid?("123")
      refute Phone.valid?("not a phone number")
      refute Phone.valid?("555-123")  # Too short
    end
  end

  describe "format_international/2" do
    test "formats US phone numbers to international format" do
      assert {:ok, formatted} = Phone.format_international("(555) 123-4567")
      assert String.starts_with?(formatted, "+1")
    end

    test "formats UK phone numbers to international format" do
      assert {:ok, formatted} = Phone.format_international("020 7946 0958", "GB")
      assert String.starts_with?(formatted, "+44")
    end

    test "returns error for invalid phone numbers" do
      assert {:error, _} = Phone.format_international("invalid")
    end
  end

  describe "format_national/2" do
    test "formats phone numbers to national format" do
      assert {:ok, formatted} = Phone.format_national("+1 555 123 4567")
      assert String.contains?(formatted, "555")
      refute String.starts_with?(formatted, "+")
    end
  end

  describe "get_country_code/2" do
    test "gets country code for US numbers" do
      assert {:ok, "US"} = Phone.get_country_code("+1 555 123 4567")
    end

    test "gets country code for UK numbers" do
      assert {:ok, "GB"} = Phone.get_country_code("+44 20 7946 0958")
    end

    test "returns error for invalid numbers" do
      assert {:error, _} = Phone.get_country_code("invalid")
    end
  end

  describe "is_mobile?/2" do
    test "identifies mobile numbers" do
      # This test might need adjustment based on actual mobile number patterns
      # For now, just test that the function works
      result = Phone.is_mobile?("+1 555 123 4567")
      assert match?({:ok, _}, result)
    end

    test "returns error for invalid numbers" do
      assert {:error, _} = Phone.is_mobile?("invalid")
    end
  end

  describe "clean/1" do
    test "removes non-phone characters" do
      cleaned = Phone.clean("Call (555) 123-4567 now!")
      assert cleaned == "(555) 123-4567"
    end

    test "normalizes spaces" do
      cleaned = Phone.clean("555   123   4567")
      assert cleaned == "555 123 4567"
    end

    test "trims whitespace" do
      cleaned = Phone.clean("  (555) 123-4567  ")
      assert cleaned == "(555) 123-4567"
    end
  end
end
