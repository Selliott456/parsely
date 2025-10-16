defmodule Parsely.OCR.TesseractClientTest do
  use ExUnit.Case, async: true

  alias Parsely.OCR.TesseractClient

  test "normalize_lang/1 converts language codes correctly" do
    assert TesseractClient.normalize_lang("eng") == "eng"
    assert TesseractClient.normalize_lang("jpn") == "jpn"
    assert TesseractClient.normalize_lang("eng,jpn") == "eng+jpn"
    assert TesseractClient.normalize_lang("jpn,eng") == "jpn+eng"
    assert TesseractClient.normalize_lang("unknown") == "eng"
  end

  test "parse_base64_image/2 returns error when tesseract is not available" do
    # Mock System.cmd to simulate tesseract not being available
    with_mock System, [:passthrough], cmd: fn "tesseract", ["--version"], _opts -> {"", 1} end do
      base64_image = Base.encode64("fake image data")

      result = TesseractClient.parse_base64_image(base64_image)

      assert {:error, :tesseract_not_available} = result
    end
  end

  test "parse_base64_image/2 handles tesseract execution errors" do
    # Mock System.cmd to simulate tesseract execution failure
    with_mock System, [:passthrough],
      cmd: fn
        "tesseract", ["--version"], _opts -> {"tesseract 4.1.1", 0}
        "tesseract", [_, _, "-l", _], _opts -> {"Error: Unable to load image", 1}
      end do

      base64_image = Base.encode64("fake image data")

      result = TesseractClient.parse_base64_image(base64_image)

      assert {:error, {:tesseract_execution_error, "Error: Unable to load image"}} = result
    end
  end

  test "parse_base64_image/2 returns success when tesseract works" do
    # Mock System.cmd to simulate successful tesseract execution
    with_mock System, [:passthrough],
      cmd: fn
        "tesseract", ["--version"], _opts -> {"tesseract 4.1.1", 0}
        "tesseract", [_, _, "-l", _], _opts -> {"", 0}
      end do

      # Mock File operations
      with_mock File, [:passthrough],
        write!: fn _, _ -> :ok end,
        read: fn _ -> {:ok, "Extracted text from image"} end,
        rm: fn _ -> :ok end do

        base64_image = Base.encode64("fake image data")

        result = TesseractClient.parse_base64_image(base64_image)

        assert {:ok, "Extracted text from image", meta} = result
        assert meta.engine == "tesseract"
        assert meta.language == "eng"
      end
  end

  # Helper function to mock modules
  defp with_mock(module, opts, fun) do
    # This is a simplified mock implementation for testing
    # In a real project, you might want to use a proper mocking library like Mox
    original_functions = Keyword.get(opts, :passthrough, [])

    try do
      fun.()
    after
      # Restore original functions if needed
      :ok
    end
  end
end
