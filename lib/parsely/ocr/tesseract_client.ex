defmodule Parsely.OCR.TesseractClient do
  @moduledoc """
  Local Tesseract OCR client implementation.

  This client uses the local Tesseract installation to extract text from images.
  It serves as a fallback when external OCR services are unavailable or rate-limited.
  """

  @behaviour Parsely.OCR.Client

  require Logger

  @doc """
  Parses a base64 encoded image using local Tesseract OCR.

  ## Parameters
  - `base64` - The base64 encoded image data (without data URI prefix)
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")
    - `:filetype` - File type (default: "jpg")

  ## Returns
  - `{:ok, text, meta}` - Success with extracted text and metadata
  - `{:error, reason}` - Error with reason
  """
  def parse_base64_image(base64, opts \\ []) do
    lang = opts[:language] || "eng"
    filetype = opts[:filetype] || "jpg"

    start_time = System.monotonic_time(:millisecond)

    try do
      # Create temporary file
      temp_file = create_temp_file(base64, filetype)

      # Run Tesseract
      result = run_tesseract(temp_file, normalize_lang(lang))

      # Clean up temp file
      File.rm(temp_file)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      case result do
        {:ok, text} ->
          meta = %{
            engine: "tesseract",
            language: normalize_lang(lang),
            processing_time_ms: duration_ms
          }

          # Emit telemetry event for OCR latency
          :telemetry.execute(
            [:parsely, :ocr, :parse],
            %{duration_ms: duration_ms},
            %{engine: "tesseract", language: normalize_lang(lang), success: true}
          )

          {:ok, text, meta}
        {:error, reason} ->
          # Emit telemetry event for failed OCR
          :telemetry.execute(
            [:parsely, :ocr, :parse],
            %{duration_ms: duration_ms},
            %{engine: "tesseract", language: normalize_lang(lang), success: false}
          )
          {:error, reason}
      end
    rescue
      error ->
        duration_ms = System.monotonic_time(:millisecond) - start_time
        Logger.error("Tesseract OCR failed: #{inspect(error)}")

        # Emit telemetry event for failed OCR
        :telemetry.execute(
          [:parsely, :ocr, :parse],
          %{duration_ms: duration_ms},
          %{engine: "tesseract", language: normalize_lang(lang), success: false}
        )

        {:error, {:tesseract_error, error}}
    end
  end

  @doc """
  Normalizes language codes to Tesseract format.
  """
  def normalize_lang(lang) do
    case lang do
      "eng" -> "eng"
      "jpn" -> "jpn"
      "eng,jpn" -> "eng+jpn"
      "jpn,eng" -> "jpn+eng"
      _ -> "eng"
    end
  end

  ## Private Functions

  defp create_temp_file(base64, filetype) do
    # Create a temporary file with the image data
    temp_dir = System.tmp_dir!()
    temp_file = Path.join(temp_dir, "ocr_#{System.unique_integer([:positive])}.#{filetype}")

    # Decode base64 and write to file
    decoded = Base.decode64!(base64)
    File.write!(temp_file, decoded)

    temp_file
  end

  defp run_tesseract(image_path, language) do
    # Check if Tesseract is available
    case System.cmd("tesseract", ["--version"], stderr_to_stdout: true) do
      {_output, 0} ->
        # Tesseract is available, run OCR
        output_file = "#{image_path}_output"

        case System.cmd("tesseract", [image_path, output_file, "-l", language], stderr_to_stdout: true) do
          {_output, 0} ->
            # Read the output file
            text_file = "#{output_file}.txt"
            case File.read(text_file) do
              {:ok, text} ->
                # Clean up output file
                File.rm(text_file)
                {:ok, String.trim(text)}
              {:error, reason} ->
                {:error, {:file_read_error, reason}}
            end
          {error_output, _exit_code} ->
            {:error, {:tesseract_execution_error, error_output}}
        end
      {_output, _exit_code} ->
        {:error, :tesseract_not_available}
    end
  end
end
