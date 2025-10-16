defmodule Parsely.Parsing.BusinessCardParser do
  @moduledoc """
  Business card parsing logic that extracts structured information from raw text.

  This module uses parallel task execution to extract different fields simultaneously,
  providing better performance on large text blobs.
  """

  alias Parsely.BusinessCard
  alias Parsely.Parsing.{English, Japanese}

  @doc """
  Parses business card text and returns a BusinessCard struct with confidence scores.

  ## Parameters
  - `text` - The raw text from the business card
  - `opts` - Options for parsing:
    - `:language` - Language code (default: "eng")

  ## Returns
  - `{:ok, %Parsely.BusinessCard{}}` - Success with parsed business card
  - `{:error, reason}` - Error with reason
  """
  def parse(text, opts \\ []) do
    lang = opts[:language] || "eng"
    parser = if String.contains?(lang, "jpn"), do: Japanese, else: English
    clean = clean(text)

    tasks =
      [
        {:email, fn -> parser.email(clean) end},
        {:phones, fn -> parser.phones(clean) end},
        {:position, fn -> parser.position(clean) end},
        {:name, fn -> parser.name(clean) end},
        {:company, fn -> parser.company(clean) end},
        {:address, fn -> parser.address(clean) end}
      ]

    results =
      Task.async_stream(tasks, fn {k, fun} -> {k, fun.()} end, timeout: 2_000)
      |> Enum.into(%{}, fn {:ok, {k, {val, conf}}} -> {k, {val, conf}} end)

    {:ok,
     %BusinessCard{
       raw_text: clean,
       language: lang,
       email: get_val(results, :email),
       phones: get_val(results, :phones) || [],
       position: get_val(results, :position),
       name: get_val(results, :name),
       company: get_val(results, :company),
       address: get_val(results, :address),
       confidence: %{
         email: get_conf(results, :email),
         phones: get_conf(results, :phones),
         position: get_conf(results, :position),
         name: get_conf(results, :name),
         company: get_conf(results, :company),
         address: get_conf(results, :address)
       }
     }}
  end

  defp clean(t) do
    t
    |> String.replace(~r/\r\n?/, "\n")
    |> String.trim()
    |> squeeze_blank_lines()
  end

  defp squeeze_blank_lines(s), do: s |> String.split("\n") |> Enum.reject(&(&1 == "")) |> Enum.join("\n")

  defp get_val(results, k) do
    case results[k] do
      {v, _c} -> v
      _ -> nil
    end
  end

  defp get_conf(results, k) do
    case results[k] do
      {_v, c} -> c
      _ -> 0.0
    end
  end
end
