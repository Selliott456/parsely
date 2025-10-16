defmodule Parsely.Parsing.JapaneseTest do
  use ExUnit.Case, async: true

  alias Parsely.Parsing.Japanese

  describe "email/1" do
    test "extracts email addresses" do
      text = "Contact: john.doe@example.com"
      {email, confidence} = Japanese.email(text)
      assert email == "john.doe@example.com"
      assert confidence == 0.9
    end

    test "returns nil and 0.0 confidence when no email found" do
      text = "No email here"
      {email, confidence} = Japanese.email(text)
      assert email == nil
      assert confidence == 0.0
    end
  end

  describe "phones/1" do
    test "extracts phone numbers" do
      text = "Call us at (555) 123-4567"
      {phones, confidence} = Japanese.phones(text)
      assert "+1 555 123 4567" in phones
      assert confidence == 0.9
    end

    test "returns empty list and 0.0 confidence when no phones found" do
      text = "No phones here"
      {phones, confidence} = Japanese.phones(text)
      assert phones == []
      assert confidence == 0.0
    end
  end

  describe "name/1" do
    test "extracts names" do
      text = "John Doe\nSoftware Engineer"
      {name, confidence} = Japanese.name(text)
      assert name == "John Doe"
      assert confidence == 0.8
    end

    test "returns nil and 0.0 confidence when no name found" do
      text = "No name here"
      {name, confidence} = Japanese.name(text)
      assert name == nil
      assert confidence == 0.0
    end
  end

  describe "company/1" do
    test "returns nil for placeholder implementation" do
      text = "Example Corp Inc\n123 Main St"
      {company, confidence} = Japanese.company(text)
      assert company == nil
      assert confidence == 0.0
    end

    test "returns nil and 0.0 confidence when no company found" do
      text = "No company here"
      {company, confidence} = Japanese.company(text)
      assert company == nil
      assert confidence == 0.0
    end
  end

  describe "position/1" do
    test "returns nil for placeholder implementation" do
      text = "Software Engineer\nJohn Doe"
      {position, confidence} = Japanese.position(text)
      assert position == nil
      assert confidence == 0.0
    end

    test "returns nil and 0.0 confidence when no position found" do
      text = "No position here"
      {position, confidence} = Japanese.position(text)
      assert position == nil
      assert confidence == 0.0
    end
  end

  describe "address/1" do
    test "extracts addresses" do
      text = "123 Main St, Anytown, CA 90210"
      {address, confidence} = Japanese.address(text)
      assert address == "123 Main St, Anytown, CA 90210"
      assert confidence == 0.6
    end

    test "returns nil and 0.0 confidence when no address found" do
      text = "No address here"
      {address, confidence} = Japanese.address(text)
      assert address == nil
      assert confidence == 0.0
    end
  end
end
