defmodule Parsely.OCR.SpaceClientTest do
  use ExUnit.Case, async: true

  alias Parsely.OCR.SpaceClient

  describe "normalize_lang/1" do
    test "normalizes language codes correctly" do
      assert SpaceClient.normalize_lang("eng") == "eng"
      assert SpaceClient.normalize_lang("jpn") == "jpn"
      assert SpaceClient.normalize_lang("eng,jpn") == "eng,jpn"
      assert SpaceClient.normalize_lang("jpn,eng") == "jpn,eng"
      assert SpaceClient.normalize_lang("invalid") == "eng"
      assert SpaceClient.normalize_lang("") == "eng"
    end
  end

  describe "parse_base64_image/2" do
    test "returns error for invalid base64" do
      # This would normally make an HTTP request, but we're testing the interface
      # In a real test, you'd mock the HTTP client
      assert {:error, _reason} = SpaceClient.parse_base64_image("invalid_base64")
    end
  end
end
