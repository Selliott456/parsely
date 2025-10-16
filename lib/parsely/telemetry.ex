defmodule Parsely.Telemetry do
  @moduledoc """
  Telemetry module for observability and monitoring.

  This module handles telemetry events for OCR operations and business card parsing,
  providing insights into performance, confidence scores, and system health.

  Events emitted:
  - [:parsely, :ocr, :parse] - OCR operation latency and success
  - [:parsely, :card, :confidence] - Business card parsing confidence scores
  """

  require Logger

  @doc """
  Attaches telemetry handlers for monitoring OCR and parsing operations.
  """
  def attach_handlers do
    # Attach handler for OCR parse events
    :telemetry.attach_many(
      "parsely-ocr-handler",
      [
        [:parsely, :ocr, :parse]
      ],
      &handle_ocr_event/4,
      nil
    )

    # Attach handler for confidence events
    :telemetry.attach_many(
      "parsely-confidence-handler",
      [
        [:parsely, :card, :confidence]
      ],
      &handle_confidence_event/4,
      nil
    )
  end

  @doc """
  Detaches all telemetry handlers.
  """
  def detach_handlers do
    :telemetry.detach("parsely-ocr-handler")
    :telemetry.detach("parsely-confidence-handler")
  end

  ## Private Functions

  defp handle_ocr_event([:parsely, :ocr, :parse], measurements, metadata, _config) do
    duration_ms = measurements.duration_ms
    engine = metadata.engine
    language = metadata.language
    success = metadata.success

    # Log OCR performance
    if success do
      Logger.info("OCR parse completed - engine: #{engine}, language: #{language}, duration_ms: #{duration_ms}")
    else
      Logger.warning("OCR parse failed - engine: #{engine}, language: #{language}, duration_ms: #{duration_ms}")
    end

    # Here you would typically send metrics to your monitoring system
    # For example, with OpenTelemetry:
    #
    # :opentelemetry_counter.add(:ocr_parse_total, 1, %{
    #   engine: engine,
    #   language: language,
    #   success: success
    # })
    #
    # :opentelemetry_histogram.record(:ocr_parse_duration_ms, duration_ms, %{
    #   engine: engine,
    #   language: language
    # })
  end

  defp handle_confidence_event([:parsely, :card, :confidence], measurements, metadata, _config) do
    overall = measurements.overall
    language = metadata.language
    parser = metadata.parser

    # Log confidence scores for monitoring
    Logger.info("Business card parsed - language: #{language}, parser: #{parser}, overall_confidence: #{overall}, name: #{measurements.name}, email: #{measurements.email}, phones: #{measurements.phones}, position: #{measurements.position}, company: #{measurements.company}, address: #{measurements.address}")

    # Track low confidence cards for investigation
    if overall < 0.5 do
      Logger.warning("Low confidence business card detected - overall_confidence: #{overall}, language: #{language}, parser: #{parser}")
    end

    # Here you would typically send metrics to your monitoring system
    # For example, with OpenTelemetry:
    #
    # :opentelemetry_histogram.record(:card_confidence_overall, overall, %{
    #   language: language,
    #   parser: parser
    # })
    #
    # :opentelemetry_histogram.record(:card_confidence_name, measurements.name, %{
    #   language: language,
    #   parser: parser
    # })
    #
    # :opentelemetry_histogram.record(:card_confidence_email, measurements.email, %{
    #   language: language,
    #   parser: parser
    # })
    #
    # # Track low confidence cards
    # if overall < 0.5 do
    #   :opentelemetry_counter.add(:card_low_confidence_total, 1, %{
    #     language: language,
    #     parser: parser
    #   })
    # end
  end

  @doc """
  Example function showing how to integrate with OpenTelemetry.
  This would be called during application startup.
  """
  def setup_opentelemetry do
    # Example OpenTelemetry setup (commented out as it requires additional dependencies)
    #
    # :opentelemetry_counter.new(:ocr_parse_total, "Total OCR parse operations")
    # :opentelemetry_histogram.new(:ocr_parse_duration_ms, "OCR parse duration in milliseconds")
    # :opentelemetry_histogram.new(:card_confidence_overall, "Overall business card confidence")
    # :opentelemetry_histogram.new(:card_confidence_name, "Name field confidence")
    # :opentelemetry_histogram.new(:card_confidence_email, "Email field confidence")
    # :opentelemetry_counter.new(:card_low_confidence_total, "Total low confidence cards")

    Logger.info("OpenTelemetry setup would be configured here")
  end

  @doc """
  Example function showing how to integrate with Honeycomb.
  This would be called during application startup.
  """
  def setup_honeycomb do
    # Example Honeycomb setup (commented out as it requires additional dependencies)
    #
    # :honeycomb.start_link([
    #   write_key: System.get_env("HONEYCOMB_WRITE_KEY"),
    #   dataset: "parsely-ocr"
    # ])

    Logger.info("Honeycomb setup would be configured here")
  end
end
