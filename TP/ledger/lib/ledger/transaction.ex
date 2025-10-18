defmodule Ledger.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ledger.Account
  alias Ledger.Currency

  schema "transactions" do
    field :type, :string
    field :amount, :decimal
    field :amount_converted, :decimal
    field :timestamp, :utc_datetime

    # Precios históricos para reproducir swaps exactamente
    field :price_origin, :decimal
    field :price_destination, :decimal
    field :conversion_rate, :decimal

    belongs_to :account_from, Account
    belongs_to :account_to, Account
    belongs_to :currency_from, Currency
    belongs_to :currency_to, Currency

    timestamps()
  end

  @valid_types ["alta_cuenta", "transferencia", "swap"]

  @doc """
  Creates a changeset for a transaction.

  ## Validations
  - type: required, must be one of #{inspect(@valid_types)}
  - amount: required, must be greater than 0
  - account_to_id: required (every transaction needs a destination)
  - timestamp: defaults to current time if not provided
  - amount_converted: optional (only used for swap transactions)
  - account_from_id: optional (null for alta_cuenta)
  - currency_from_id, currency_to_id: optional but recommended for queries
  """
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :type,
      :amount,
      :amount_converted,
      :timestamp,
      :account_from_id,
      :account_to_id,
      :currency_from_id,
      :currency_to_id,
      :price_origin,
      :price_destination,
      :conversion_rate
    ])
    |> validate_required([:type, :amount, :account_to_id])
    |> validate_inclusion(:type, @valid_types)
    |> validate_number(:amount, greater_than: Decimal.new("0"))
    |> validate_number(:amount_converted, greater_than_or_equal_to: Decimal.new("0"))
    |> validate_number(:price_origin, greater_than_or_equal_to: Decimal.new("0"))
    |> validate_number(:price_destination, greater_than_or_equal_to: Decimal.new("0"))
    |> validate_number(:conversion_rate, greater_than_or_equal_to: Decimal.new("0"))
    |> foreign_key_constraint(:account_from_id)
    |> foreign_key_constraint(:account_to_id)
    |> foreign_key_constraint(:currency_from_id)
    |> foreign_key_constraint(:currency_to_id)
    |> put_default_timestamp()
  end

  defp put_default_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil ->
        put_change(changeset, :timestamp, DateTime.utc_now() |> DateTime.truncate(:second))

      timestamp ->
        put_change(changeset, :timestamp, DateTime.truncate(timestamp, :second))
    end
  end
end
