defmodule Parsely.BusinessCards.BusinessCard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "business_cards" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :position, :string
    field :image_url, :string
    field :ocr_data, :map
    field :is_virtual, :boolean, default: false
    field :notes, {:array, :map}, default: []

    belongs_to :user, Parsely.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(business_card, attrs) do
    business_card
    |> cast(attrs, [:name, :email, :phone, :company, :position, :image_url, :ocr_data, :is_virtual, :user_id, :notes])
    |> validate_required([:user_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> foreign_key_constraint(:user_id)
  end

  def virtual_card_changeset(business_card, attrs) do
    business_card
    |> cast(attrs, [:name, :email, :phone, :company, :position, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> put_change(:is_virtual, true)
    |> foreign_key_constraint(:user_id)
  end
end
