defmodule Parsely.BusinessCards.BusinessCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "business_cards" do
    field :name, :string
    field :email, :string
    field :primary_phone, :string
    field :secondary_phone, :string
    field :company, :string
    field :position, :string
    field :address, :string
    field :image_url, :string
    field :ocr_data, :map
    field :notes, {:array, :map}, default: []
    field :notes_text, :string, virtual: true

    belongs_to :user, Parsely.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(business_card, attrs) do
    business_card
    |> cast(attrs, [:name, :email, :primary_phone, :secondary_phone, :company, :position, :address, :image_url, :ocr_data, :user_id, :notes, :notes_text])
    |> validate_required([:user_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> foreign_key_constraint(:user_id)
    |> convert_notes_text_to_notes()
  end

  defp convert_notes_text_to_notes(changeset) do
    case get_change(changeset, :notes_text) do
      nil -> changeset
      notes_text when is_binary(notes_text) and byte_size(notes_text) > 0 ->
        # Convert text to array of maps format
        formatted_notes = [%{
          "note" => notes_text,
          "date" => DateTime.utc_now() |> DateTime.to_iso8601()
        }]
        put_change(changeset, :notes, formatted_notes)
      _ ->
        # Empty or invalid text, set empty array
        put_change(changeset, :notes, [])
    end
  end
end
