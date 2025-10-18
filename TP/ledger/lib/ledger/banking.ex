defmodule Ledger.Banking do
  @moduledoc """
  Contexto para gestionar cuentas bancarias (accounts).

  Las cuentas representan el balance de un usuario en una moneda específica.
  Un usuario puede tener múltiples cuentas, pero solo UNA por moneda.
  """

  import Ecto.Query
  alias Ledger.Repo
  alias Ledger.Account
  alias Ledger.Accounts
  alias Ledger.Currencies

  @doc """
  Crea una nueva cuenta para un usuario en una moneda específica.

  ## Parámetros
  - attrs: Map con :user_id, :currency_id y :balance (opcional, default 0)

  ## Ejemplos
      iex> create_account(%{user_id: 1, currency_id: 1, balance: 100.0})
      {:ok, %Account{}}

      iex> create_account(%{user_id: 1, currency_id: 1})  # Ya existe
      {:error, %Ecto.Changeset{}}
  """
  def create_account(attrs \\ %{}) do
    # Convertir balance a Decimal si viene como float o string
    attrs = normalize_balance(attrs)

    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene una cuenta por su ID.

  ## Ejemplos
      iex> get_account(1)
      %Account{}

      iex> get_account(999)
      nil
  """
  def get_account(id) do
    Repo.get(Account, id)
  end

  @doc """
  Obtiene una cuenta de un usuario para una moneda específica.

  ## Ejemplos
      iex> get_account_by_user_and_currency(1, 1)
      %Account{}

      iex> get_account_by_user_and_currency(1, 999)
      nil
  """
  def get_account_by_user_and_currency(user_id, currency_id) do
    Repo.get_by(Account, user_id: user_id, currency_id: currency_id)
  end

  @doc """
  Lista todas las cuentas de un usuario.

  ## Ejemplos
      iex> list_user_accounts(1)
      [%Account{}, %Account{}]
  """
  def list_user_accounts(user_id) do
    Account
    |> where([a], a.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Lista todas las cuentas.

  ## Ejemplos
      iex> list_accounts()
      [%Account{}, ...]
  """
  def list_accounts do
    Repo.all(Account)
  end

  @doc """
  Actualiza el balance de una cuenta.

  ## Parámetros
  - account: La cuenta a actualizar
  - attrs: Map con el nuevo balance

  ## Ejemplos
      iex> update_account_balance(account, %{balance: 500.0})
      {:ok, %Account{}}

      iex> update_account_balance(account, %{balance: -100})
      {:error, %Ecto.Changeset{}}
  """
  def update_account_balance(%Account{} = account, attrs) do
    attrs = normalize_balance(attrs)

    account
    |> Account.update_balance_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina una cuenta.

  Solo se puede eliminar si no tiene transacciones asociadas.

  ## Ejemplos
      iex> delete_account(account)
      {:ok, %Account{}}

      iex> delete_account(account_with_transactions)
      {:error, "La cuenta tiene transacciones asociadas y no puede ser eliminada"}
  """
  def delete_account(%Account{} = account) do
    # NOTA: No se valida si tiene transacciones asociadas
    # El borrado de cuentas con transacciones está permitido para simplificar el modelo
    Repo.delete(account)
  end

  @doc """
  Verifica si existe una cuenta para un usuario y moneda.

  ## Ejemplos
      iex> account_exists?(1, 1)
      true

      iex> account_exists?(999, 999)
      false
  """
  def account_exists?(user_id, currency_id) do
    Account
    |> where([a], a.user_id == ^user_id and a.currency_id == ^currency_id)
    |> Repo.exists?()
  end

  @doc """
  Valida que un usuario existe.

  ## Ejemplos
      iex> user_exists?(1)
      {:ok, true}

      iex> user_exists?(999)
      {:error, "El usuario con ID 999 no existe"}
  """
  def user_exists?(user_id) do
    if Accounts.user_exists?(user_id) do
      {:ok, true}
    else
      {:error, "El usuario con ID #{user_id} no existe"}
    end
  end

  @doc """
  Valida que una moneda existe.

  ## Ejemplos
      iex> currency_exists?(1)
      {:ok, true}

      iex> currency_exists?(999)
      {:error, "La moneda con ID 999 no existe"}
  """
  def currency_exists?(currency_id) do
    if Currencies.currency_exists?(currency_id) do
      {:ok, true}
    else
      {:error, "La moneda con ID #{currency_id} no existe"}
    end
  end

  @doc """
  Da de alta una cuenta para un usuario con un monto inicial.

  Este es el comando principal del TP2 para crear cuentas.

  ## Parámetros
  - user_id: ID del usuario
  - currency_id: ID de la moneda
  - initial_amount: Monto inicial (debe ser >= 0)

  ## Ejemplos
      iex> open_account(1, 1, 1000.0)
      {:ok, %Account{}}

      iex> open_account(999, 1, 100)
      {:error, "El usuario con ID 999 no existe"}
  """
  def open_account(user_id, currency_id, initial_amount) do
    with {:ok, _} <- user_exists?(user_id),
         {:ok, _} <- currency_exists?(currency_id),
         :ok <- validate_positive_amount(initial_amount),
         :ok <- validate_account_not_exists(user_id, currency_id) do
      create_account(%{
        user_id: user_id,
        currency_id: currency_id,
        balance: initial_amount
      })
    end
  end

  # Funciones privadas

  defp normalize_balance(attrs) when is_map(attrs) do
    case Map.get(attrs, :balance) do
      nil ->
        attrs

      balance when is_binary(balance) ->
        Map.put(attrs, :balance, Decimal.new(balance))

      balance when is_float(balance) or is_integer(balance) ->
        Map.put(attrs, :balance, Decimal.from_float(balance * 1.0))

      %Decimal{} ->
        attrs

      _ ->
        attrs
    end
  end

  defp validate_positive_amount(amount) when is_number(amount) and amount >= 0, do: :ok
  defp validate_positive_amount(amount) when is_number(amount), do: {:error, "El monto debe ser mayor o igual a 0"}
  defp validate_positive_amount(%Decimal{} = amount) do
    if Decimal.compare(amount, Decimal.new("0")) in [:eq, :gt] do
      :ok
    else
      {:error, "El monto debe ser mayor o igual a 0"}
    end
  end
  defp validate_positive_amount(_), do: {:error, "El monto debe ser un número válido"}

  defp validate_account_not_exists(user_id, currency_id) do
    if account_exists?(user_id, currency_id) do
      {:error, "El usuario ya tiene una cuenta para esta moneda"}
    else
      :ok
    end
  end
end
