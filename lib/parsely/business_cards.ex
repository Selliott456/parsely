defmodule Parsely.BusinessCards do
  @moduledoc """
  The BusinessCards context.
  """

  import Ecto.Query, warn: false
  alias Parsely.Repo
  alias Parsely.BusinessCards.{BusinessCard, BusinessCardNote}

  @doc """
  Returns the list of business cards for a user.

  ## Examples

      iex> list_business_cards(user_id)
      [%BusinessCard{}, ...]

  """
  def list_business_cards(user_id) do
    BusinessCard
    |> where(user_id: ^user_id)
    |> preload(:notes)
    |> order_by([bc], [desc: bc.inserted_at])
    |> Repo.all()
  end

  @doc """
  Gets a single business card.

  Raises `Ecto.NoResultsError` if the Business Card does not exist.

  ## Examples

      iex> get_business_card!(123)
      %BusinessCard{}

      iex> get_business_card!(456)
      ** (Ecto.NoResultsError)

  """
  def get_business_card!(id, user_id) do
    BusinessCard
    |> where(id: ^id, user_id: ^user_id)
    |> preload(:notes)
    |> Repo.one!()
  end

  @doc """
  Creates a business card.

  ## Examples

      iex> create_business_card(%{field: value})
      {:ok, %BusinessCard{}}

      iex> create_business_card(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_business_card(attrs \\ %{}) do
    %BusinessCard{}
    |> BusinessCard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a virtual business card.

  ## Examples

      iex> create_virtual_card(%{field: value})
      {:ok, %BusinessCard{}}

      iex> create_virtual_card(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_virtual_card(attrs \\ %{}) do
    %BusinessCard{}
    |> BusinessCard.virtual_card_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a business card.

  ## Examples

      iex> update_business_card(business_card, %{field: new_value})
      {:ok, %BusinessCard{}}

      iex> update_business_card(business_card, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_business_card(%BusinessCard{} = business_card, attrs) do
    business_card
    |> BusinessCard.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a business card.

  ## Examples

      iex> delete_business_card(business_card)
      {:ok, %BusinessCard{}}

      iex> delete_business_card(business_card)
      {:error, %Ecto.Changeset{}}

  """
  def delete_business_card(%BusinessCard{} = business_card) do
    Repo.delete(business_card)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking business card changes.

  ## Examples

      iex> change_business_card(business_card)
      %Ecto.Changeset{data: %BusinessCard{}}

  """
  def change_business_card(%BusinessCard{} = business_card, attrs \\ %{}) do
    BusinessCard.changeset(business_card, attrs)
  end

  @doc """
  Checks if a business card with the same email already exists for the user.
  """
  def duplicate_exists?(user_id, email) when is_binary(email) do
    BusinessCard
    |> where(user_id: ^user_id, email: ^email)
    |> Repo.exists?()
  end

  def duplicate_exists?(_user_id, _email), do: false

  @doc """
  Creates a note for a business card.

  ## Examples

      iex> create_note(%{field: value})
      {:ok, %BusinessCardNote{}}

      iex> create_note(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_note(attrs \\ %{}) do
    %BusinessCardNote{}
    |> BusinessCardNote.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all notes for a business card.
  """
  def list_notes(business_card_id) do
    BusinessCardNote
    |> where(business_card_id: ^business_card_id)
    |> order_by([n], [desc: n.date_added])
    |> Repo.all()
  end

  @doc """
  Deletes a note.
  """
  def delete_note(%BusinessCardNote{} = note) do
    Repo.delete(note)
  end
end
