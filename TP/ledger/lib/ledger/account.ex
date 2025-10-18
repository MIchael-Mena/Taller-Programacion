defmodule Ledger.Account do
  @moduledoc """
  Schema para la entidad Account (Cuenta).

  Representa una cuenta de un usuario en una moneda específica.
  Un usuario puede tener múltiples cuentas, pero solo UNA por moneda.

  ## Relaciones
  - belongs_to :user - El usuario dueño de la cuenta
  - belongs_to :currency - La moneda de la cuenta

  ## Validaciones
  - user_id: requerido, debe existir en la tabla users
  - currency_id: requerido, debe existir en la tabla currencies
  - balance: requerido, debe ser >= 0
  - Restricción única: (user_id, currency_id) - un usuario solo puede tener una cuenta por moneda
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.User
  alias Ledger.Currency

  schema "accounts" do
    belongs_to :user, User
    belongs_to :currency, Currency
    field :balance, :decimal, default: Decimal.new("0.0")

    timestamps(type: :naive_datetime)
  end

  @doc """
  Changeset para crear una nueva cuenta.

  ## Validaciones
  - user_id: requerido
  - currency_id: requerido
  - balance: requerido, debe ser >= 0
  - Verifica que no exista ya una cuenta para ese usuario y moneda (unicidad)
  """
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:user_id, :currency_id, :balance])
    |> validate_required([:user_id, :currency_id, :balance])
    |> validate_number(:balance, greater_than_or_equal_to: Decimal.new("0"))
    |> foreign_key_constraint(:user_id, message: "El usuario especificado no existe")
    |> foreign_key_constraint(:currency_id, message: "La moneda especificada no existe")
    |> unique_constraint([:user_id, :currency_id],
      name: :accounts_user_currency_index,
      message: "El usuario ya tiene una cuenta para esta moneda"
    )
  end

  @doc """
  Changeset para actualizar el balance de una cuenta.
  Solo permite modificar el balance.
  """
  def update_balance_changeset(account, attrs) do
    account
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_number(:balance, greater_than_or_equal_to: Decimal.new("0"))
  end
end
