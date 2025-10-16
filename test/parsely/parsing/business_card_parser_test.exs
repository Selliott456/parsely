defmodule Parsely.Parsing.BusinessCardParserTest do
  use ExUnit.Case, async: true

  alias Parsely.Parsing.BusinessCardParser

  describe "parse/2" do
    test "parses English business card text" do
      text = """
      John Doe
      Software Engineer
      Example Corp
      john.doe@example.com
      +1 (555) 123-4567
      """

      assert {:ok, result} = BusinessCardParser.parse(text, language: "eng")
      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
      assert Map.has_key?(result, :raw_text)
    end

    test "parses Japanese business card text" do
      text = """
      田中太郎
      営業部長
      株式会社サンプル
      tanaka@sample.co.jp
      03-1234-5678
      """

      assert {:ok, result} = BusinessCardParser.parse(text, language: "jpn")
      assert is_map(result)
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :email)
      assert Map.has_key?(result, :raw_text)
    end

    test "handles empty text" do
      assert {:ok, result} = BusinessCardParser.parse("", language: "eng")
      assert is_map(result)
    end

    test "defaults to English when no language specified" do
      text = """
      John Doe
      Software Engineer
      Example Corp
      john.doe@example.com
      +1 (555) 123-4567
      """

      assert {:ok, result} = BusinessCardParser.parse(text)
      assert is_map(result)
    end
  end
end
