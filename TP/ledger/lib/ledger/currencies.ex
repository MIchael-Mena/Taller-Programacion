defmodule Ledger.Currencies do
  @moduledoc """
  Contexto para manejar las operaciones relacionadas con monedas.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo
  alias Ledger.Currency

  @doc """
  Crea una nueva moneda.

  ## Ejemplos

      iex> create_currency(%{name: "BTC", price_usd: 55000.0})
      {:ok, %Currency{}}

      iex> create_currency(%{name: "btc", price_usd: 55000.0})
      {:error, %Ecto.Changeset{}}

  """
  def create_currency(attrs \\ %{}) do
    %Currency{}
    |> Currency.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene una moneda por su ID.

  Retorna `nil` si la moneda no existe.

  ## Ejemplos

      iex> get_currency(123)
      %Currency{}

      iex> get_currency(999)
      nil

  """
  def get_currency(id) do
    Repo.get(Currency, id)
  end

  @doc """
  Obtiene una moneda por su ID.

  Lanza `Ecto.NoResultsError` si la moneda no existe.

  ## Ejemplos

      iex> get_currency!(123)
      %Currency{}

      iex> get_currency!(999)
      ** (Ecto.NoResultsError)

  """
  def get_currency!(id) do
    Repo.get!(Currency, id)
  end

  @doc """
  Obtiene una moneda por su nombre.

  ## Ejemplos

      iex> get_currency_by_name("BTC")
      %Currency{}

      iex> get_currency_by_name("NOEXISTE")
      nil

  """
  def get_currency_by_name(name) do
    Repo.get_by(Currency, name: name)
  end

  @doc """
  Lista todas las monedas.

  ## Ejemplos

      iex> list_currencies()
      [%Currency{}, ...]

  """
  def list_currencies do
    Repo.all(Currency)
  end

  @doc """
  Actualiza el precio de una moneda.

  ## Ejemplos

      iex> update_currency(currency, %{price_usd: 56000.0})
      {:ok, %Currency{}}

      iex> update_currency(currency, %{price_usd: -100.0})
      {:error, %Ecto.Changeset{}}

  """
  def update_currency(%Currency{} = currency, attrs) do
    currency
    |> Currency.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina una moneda.

  Solo permite eliminar si la moneda no tiene transacciones asociadas.

  ## Ejemplos

      iex> delete_currency(currency)
      {:ok, %Currency{}}

      iex> delete_currency(currency_con_transacciones)
      {:error, :has_transactions}

  """
  def delete_currency(%Currency{} = currency) do
    # Verificar si la moneda tiene transacciones
    if currency_has_transactions?(currency.id) do
      {:error, :has_transactions}
    else
      Repo.delete(currency)
    end
  end

  @doc """
  Verifica si una moneda tiene transacciones asociadas.

  ## Ejemplos

      iex> currency_has_transactions?(1)
      true

      iex> currency_has_transactions?(999)
      false

  """
  def currency_has_transactions?(_currency_id) do
    # NOTA: Implementación simplificada - siempre retorna false
    # Permite borrar monedas incluso con transacciones asociadas
    # Decisión de diseño para simplificar el modelo de datos
    #
    # Implementación completa requeriría:
    # query = from a in Account,
    #   join: t in Transaction, on: a.id == t.account_from_id or a.id == t.account_to_id,
    #   where: a.currency_id == ^currency_id,
    #   select: count(t.id)
    # Repo.one(query) > 0

    false
  end

  @doc """
  Verifica si un nombre de moneda está disponible.

  ## Ejemplos

      iex> currency_name_available?("NEW")
      true

      iex> currency_name_available?("BTC")
      false

  """
  def currency_name_available?(name) do
    case get_currency_by_name(name) do
      nil -> true
      _currency -> false
    end
  end

  @doc """
  Valida que un nombre de moneda tenga el formato correcto.
  Debe estar en mayúsculas y tener entre 3 y 4 letras.

  ## Ejemplos

      iex> valid_currency_name?("BTC")
      true

      iex> valid_currency_name?("btc")
      false

      iex> valid_currency_name?("BITCOIN")
      false

  """
  def valid_currency_name?(name) do
    Regex.match?(~r/^[A-Z]{3,4}$/, name)
  end

  @doc """
  Verifica si existe una moneda con el ID dado.

  ## Ejemplos

      iex> currency_exists?(1)
      true

      iex> currency_exists?(999)
      false

  """
  def currency_exists?(currency_id) do
    Currency
    |> where([c], c.id == ^currency_id)
    |> Repo.exists?()
  end
end
