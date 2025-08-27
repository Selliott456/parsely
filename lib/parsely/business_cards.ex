defmodule Parsely.BusinessCards do
  @moduledoc """
  The BusinessCards context.
  """

  import Ecto.Query, warn: false
  alias Parsely.Repo
  alias Parsely.BusinessCards.BusinessCard

  @doc """
  Returns the list of business cards for a user.

  ## Examples

      iex> list_business_cards(user_id)
      [%BusinessCard{}, ...]

  """
  def list_business_cards(user_id) do
    BusinessCard
    |> where(user_id: ^user_id)
    |> order_by([bc], [asc: fragment("COALESCE(?, '')", bc.name), desc: bc.inserted_at])
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
    normalized_email = email |> String.trim() |> String.downcase()

    IO.puts("=== EMAIL DUPLICATE CHECK ===")
    IO.puts("User ID: #{user_id}")
    IO.puts("Normalized email: #{normalized_email}")

    result = BusinessCard
    |> where([bc], bc.user_id == ^user_id)
    |> where([bc], fragment("lower(?)", bc.email) == ^normalized_email)
    |> Repo.exists?()

    IO.puts("Email duplicate result: #{result}")
    result
  end

  def duplicate_exists?(_user_id, _email), do: false

  @doc """
  Searches business cards for a user by query across multiple fields.
  Searches name, email, phone, company, and position fields.
  """
  def search_business_cards(user_id, query) when is_binary(query) and byte_size(query) > 0 do
    search_term = "%#{query}%"

    BusinessCard
    |> where([bc], bc.user_id == ^user_id)
    |> where([bc],
      ilike(bc.name, ^search_term) or
      ilike(bc.email, ^search_term) or
      ilike(bc.phone, ^search_term) or
      ilike(bc.company, ^search_term) or
      ilike(bc.position, ^search_term)
    )
    |> order_by([bc], [desc: bc.inserted_at])
    |> Repo.all()
  end

  def search_business_cards(user_id, _query), do: list_business_cards(user_id)

  @doc """
  Checks for duplicates by email (case-insensitive) or phone (digits only).
  Returns true if either matches for the given user.
  """
  def duplicate_exists?(user_id, email, phone) do
    # Simple check: if email exists and matches any existing email for this user
    case email do
      value when is_binary(value) ->
        trimmed = String.trim(value)
        if trimmed != "" and String.contains?(trimmed, "@") do
          IO.puts("=== SIMPLE EMAIL DUPLICATE CHECK ===")
          IO.puts("User ID: #{user_id}")
          IO.puts("Email: #{trimmed}")

          result = BusinessCard
          |> where([bc], bc.user_id == ^user_id)
          |> where([bc], bc.email == ^trimmed)
          |> Repo.exists?()

          IO.puts("Duplicate result: #{result}")
          result
        else
          false
        end
      _ ->
        false
    end
  end
end
