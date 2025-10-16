defmodule Parsely.BusinessCard do
  @moduledoc """
  Typed struct representing a parsed business card with confidence scores.

  This struct provides a consistent interface for business card data
  along with confidence scores for each extracted field.
  """

  @enforce_keys [:raw_text]
  defstruct [
    :name,
    :email,
    :phones,
    :company,
    :position,
    :address,
    :language,
    :raw_text,
    # per-field confidences 0..1
    confidence: %{
      name: 0.0,
      email: 0.0,
      phones: 0.0,
      company: 0.0,
      position: 0.0,
      address: 0.0
    }
  ]

  @type t :: %__MODULE__{
    name: String.t() | nil,
    email: String.t() | nil,
    phones: list(String.t()) | nil,
    company: String.t() | nil,
    position: String.t() | nil,
    address: String.t() | nil,
    language: String.t() | nil,
    raw_text: String.t(),
    confidence: %{
      name: float(),
      email: float(),
      phones: float(),
      company: float(),
      position: float(),
      address: float()
    }
  }

  @doc """
  Creates a new BusinessCard struct with default confidence scores.
  """
  def new(raw_text, opts \\ []) do
    %__MODULE__{
      raw_text: raw_text,
      language: opts[:language],
      name: opts[:name],
      email: opts[:email],
      phones: opts[:phones],
      company: opts[:company],
      position: opts[:position],
      address: opts[:address],
      confidence: opts[:confidence] || %{
        name: 0.0,
        email: 0.0,
        phones: 0.0,
        company: 0.0,
        position: 0.0,
        address: 0.0
      }
    }
  end

  @doc """
  Updates a field in the BusinessCard with a confidence score.
  """
  def put_field(business_card, field, value, confidence \\ 0.0) when field in [:name, :email, :phones, :company, :position, :address] do
    business_card
    |> Map.put(field, value)
    |> Map.put(:confidence, Map.put(business_card.confidence, field, confidence))
  end

  @doc """
  Gets the overall confidence score (average of all field confidences).
  """
  def overall_confidence(%__MODULE__{confidence: confidence}) do
    confidence
    |> Map.values()
    |> Enum.sum()
    |> Kernel./(6)  # 6 fields total
  end

  @doc """
  Converts the BusinessCard to a map format compatible with the existing API.
  """
  def to_map(%__MODULE__{} = business_card) do
    %{
      name: business_card.name,
      email: business_card.email,
      primary_phone: List.first(business_card.phones || []),
      secondary_phone: Enum.at(business_card.phones || [], 1),
      company: business_card.company,
      position: business_card.position,
      address: business_card.address,
      raw_text: business_card.raw_text,
      language: business_card.language,
      confidence: business_card.confidence,
      overall_confidence: overall_confidence(business_card)
    }
  end
end
