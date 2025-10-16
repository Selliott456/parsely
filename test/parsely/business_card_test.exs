defmodule Parsely.BusinessCardTest do
  use ExUnit.Case, async: true

  alias Parsely.BusinessCard

  describe "new/2" do
    test "creates a new BusinessCard with default confidence scores" do
      business_card = BusinessCard.new("John Doe\nSoftware Engineer", name: "John Doe")

      assert business_card.raw_text == "John Doe\nSoftware Engineer"
      assert business_card.name == "John Doe"
      assert business_card.confidence.name == 0.0
      assert business_card.confidence.email == 0.0
    end

    test "creates a BusinessCard with custom confidence scores" do
      confidence = %{name: 0.9, email: 0.8, phones: 0.0, company: 0.0, position: 0.0, address: 0.0}

      business_card = BusinessCard.new("test",
        name: "John Doe",
        email: "john@example.com",
        confidence: confidence
      )

      assert business_card.name == "John Doe"
      assert business_card.email == "john@example.com"
      assert business_card.confidence.name == 0.9
      assert business_card.confidence.email == 0.8
    end
  end

  describe "put_field/4" do
    test "updates a field with confidence score" do
      business_card = BusinessCard.new("test")

      updated = BusinessCard.put_field(business_card, :name, "John Doe", 0.9)

      assert updated.name == "John Doe"
      assert updated.confidence.name == 0.9
    end

    test "updates multiple fields" do
      business_card = BusinessCard.new("test")

      updated = business_card
      |> BusinessCard.put_field(:name, "John Doe", 0.9)
      |> BusinessCard.put_field(:email, "john@example.com", 0.95)

      assert updated.name == "John Doe"
      assert updated.email == "john@example.com"
      assert updated.confidence.name == 0.9
      assert updated.confidence.email == 0.95
    end
  end

  describe "overall_confidence/1" do
    test "calculates average confidence across all fields" do
      confidence = %{
        name: 0.9,
        email: 0.8,
        phones: 0.7,
        company: 0.6,
        position: 0.5,
        address: 0.4
      }

      business_card = BusinessCard.new("test", confidence: confidence)

      expected = (0.9 + 0.8 + 0.7 + 0.6 + 0.5 + 0.4) / 6
      assert Float.round(BusinessCard.overall_confidence(business_card), 2) == expected
    end

    test "handles zero confidence scores" do
      business_card = BusinessCard.new("test")

      assert BusinessCard.overall_confidence(business_card) == 0.0
    end
  end

  describe "to_map/1" do
    test "converts BusinessCard to map format" do
      phones = ["(555) 123-4567", "(555) 987-6543"]
      confidence = %{name: 0.9, email: 0.8, phones: 0.7, company: 0.6, position: 0.5, address: 0.4}

      business_card = BusinessCard.new("raw text",
        name: "John Doe",
        email: "john@example.com",
        phones: phones,
        company: "Example Corp",
        position: "Software Engineer",
        address: "123 Main St",
        language: "eng",
        confidence: confidence
      )

      result = BusinessCard.to_map(business_card)

      assert result.name == "John Doe"
      assert result.email == "john@example.com"
      assert result.primary_phone == "(555) 123-4567"
      assert result.secondary_phone == "(555) 987-6543"
      assert result.company == "Example Corp"
      assert result.position == "Software Engineer"
      assert result.address == "123 Main St"
      assert result.raw_text == "raw text"
      assert result.language == "eng"
      assert result.confidence == confidence
      assert is_float(result.overall_confidence)
    end

    test "handles nil phones correctly" do
      business_card = BusinessCard.new("test", phones: nil)
      result = BusinessCard.to_map(business_card)

      assert result.primary_phone == nil
      assert result.secondary_phone == nil
    end

    test "handles single phone correctly" do
      business_card = BusinessCard.new("test", phones: ["(555) 123-4567"])
      result = BusinessCard.to_map(business_card)

      assert result.primary_phone == "(555) 123-4567"
      assert result.secondary_phone == nil
    end
  end
end
