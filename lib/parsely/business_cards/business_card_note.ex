defmodule Parsely.BusinessCards.BusinessCardNote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "business_card_notes" do
    field :note, :string
    field :date_added, :utc_datetime_usec

    belongs_to :business_card, Parsely.BusinessCards.BusinessCard

    timestamps()
  end

  @doc false
  def changeset(business_card_note, attrs) do
    business_card_note
    |> cast(attrs, [:note, :date_added, :business_card_id])
    |> validate_required([:note, :business_card_id])
    |> foreign_key_constraint(:business_card_id)
  end

  def create_changeset(business_card_note, attrs) do
    business_card_note
    |> cast(attrs, [:note, :business_card_id])
    |> validate_required([:note, :business_card_id])
    |> put_change(:date_added, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:microsecond))
    |> foreign_key_constraint(:business_card_id)
  end
end
