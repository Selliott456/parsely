defmodule Parsely.TelemetryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Parsely.Telemetry

  setup do
    # Attach handlers for testing
    Telemetry.attach_handlers()

    on_exit(fn ->
      Telemetry.detach_handlers()
    end)
  end

  test "OCR parse telemetry events are emitted and handled" do
    log = capture_log(fn ->
      # Emit OCR parse event
      :telemetry.execute(
        [:parsely, :ocr, :parse],
        %{duration_ms: 150},
        %{engine: "ocr.space", language: "eng", success: true}
      )
    end)

    assert log =~ "OCR parse completed"
    assert log =~ "engine: ocr.space"
    assert log =~ "language: eng"
    assert log =~ "duration_ms: 150"
  end

  test "OCR parse failure telemetry events are emitted and handled" do
    log = capture_log(fn ->
      # Emit OCR parse failure event
      :telemetry.execute(
        [:parsely, :ocr, :parse],
        %{duration_ms: 5000},
        %{engine: "ocr.space", language: "eng", success: false}
      )
    end)

    assert log =~ "OCR parse failed"
    assert log =~ "engine: ocr.space"
    assert log =~ "language: eng"
    assert log =~ "duration_ms: 5000"
  end

  test "confidence telemetry events are emitted and handled" do
    log = capture_log(fn ->
      # Emit confidence event
      :telemetry.execute(
        [:parsely, :card, :confidence],
        %{
          name: 0.8,
          email: 0.95,
          phones: 0.7,
          position: 0.6,
          company: 0.75,
          address: 0.5,
          overall: 0.72
        },
        %{language: "eng", parser: "Parsely.Parsing.English"}
      )
    end)

    assert log =~ "Business card parsed"
    assert log =~ "language: eng"
    assert log =~ "parser: Parsely.Parsing.English"
    assert log =~ "overall_confidence: 0.72"
    assert log =~ "name: 0.8"
    assert log =~ "email: 0.95"
  end

  test "low confidence cards are flagged" do
    log = capture_log(fn ->
      # Emit low confidence event
      :telemetry.execute(
        [:parsely, :card, :confidence],
        %{
          name: 0.2,
          email: 0.3,
          phones: 0.1,
          position: 0.4,
          company: 0.2,
          address: 0.1,
          overall: 0.22
        },
        %{language: "eng", parser: "Parsely.Parsing.English"}
      )
    end)

    assert log =~ "Business card parsed"
    assert log =~ "overall_confidence: 0.22"
    assert log =~ "Low confidence business card detected"
  end

  test "telemetry handlers can be detached and reattached" do
    # Detach handlers
    Telemetry.detach_handlers()

    # Emit event - should not be logged
    log = capture_log(fn ->
      :telemetry.execute(
        [:parsely, :ocr, :parse],
        %{duration_ms: 100},
        %{engine: "mock", language: "eng", success: true}
      )
    end)

    refute log =~ "OCR parse completed"

    # Reattach handlers
    Telemetry.attach_handlers()

    # Emit event - should be logged
    log = capture_log(fn ->
      :telemetry.execute(
        [:parsely, :ocr, :parse],
        %{duration_ms: 100},
        %{engine: "mock", language: "eng", success: true}
      )
    end)

    assert log =~ "OCR parse completed"
  end

  test "setup functions exist for OpenTelemetry and Honeycomb integration" do
    # These functions should exist and not raise errors
    assert Telemetry.setup_opentelemetry() == :ok
    assert Telemetry.setup_honeycomb() == :ok
  end
end
