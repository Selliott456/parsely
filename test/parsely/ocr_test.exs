defmodule Parsely.OCRTest do
  use ExUnit.Case, async: true

  alias Parsely.OCR

  setup do
    # Ensure we're using the mock client for tests
    Application.put_env(:parsely, :ocr_client, :mock)
    :ok
  end

  describe "extract_text/2" do
    test "extracts text using mock client in test environment" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      assert {:ok, text, meta} = OCR.extract_text(base64_image)
      assert is_binary(text)
      assert is_map(meta)
      assert Map.has_key?(meta, :OCRExitCode)
    end

    test "extracts text with language option" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      assert {:ok, text, _meta} = OCR.extract_text(base64_image, language: "jpn")
      assert is_binary(text)
    end

    test "allows client override for testing" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      # Test with mock client explicitly
      assert {:ok, text, _meta} = OCR.extract_text(base64_image, client: Parsely.OCR.MockClient)
      assert is_binary(text)
    end
  end

  describe "extract_business_card_info/2" do
    test "extracts business card information" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      assert {:ok, result} = OCR.extract_business_card_info(base64_image)
      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
      assert Map.has_key?(result, :raw_text)
      assert Map.has_key?(result, :confidence)
      assert Map.has_key?(result, :overall_confidence)
    end

    test "handles Japanese language" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      assert {:ok, result} = OCR.extract_business_card_info(base64_image, language: "jpn")
      assert is_map(result)
      assert Map.has_key?(result, :confidence)
    end
  end

  describe "extract_business_card_struct/2" do
    test "extracts business card information and returns struct" do
      base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="

      assert {:ok, business_card} = OCR.extract_business_card_struct(base64_image, language: "eng")

      # Verify the result is a BusinessCard struct
      assert %Parsely.BusinessCard{} = business_card
      assert is_binary(business_card.raw_text)
      assert is_map(business_card.confidence)
      assert is_float(Parsely.BusinessCard.overall_confidence(business_card))
    end
  end
end
