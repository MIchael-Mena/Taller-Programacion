defmodule Ledger.Currency do
  use Ecto.Schema
  import Ecto.Changeset

  schema "currencies" do
    field :name, :string
    field :price_usd, :float
    field :inserted_at, :naive_datetime
    field :updated_at, :naive_datetime
  end

  @doc """
  Crea un changeset para validar los datos de la moneda.
  """
  def changeset(currency, attrs) do
    currency
    |> cast(attrs, [:name, :price_usd])
    |> validate_required([:name, :price_usd])
    |> validate_currency_name()
    |> validate_price()
    |> unique_constraint(:name, name: :currencies_name_index)
    |> put_timestamps()
  end

  @doc """
  Crea un changeset para actualizar el precio de la moneda.
  El nombre no puede ser editado.
  """
  def update_changeset(currency, attrs) do
    currency
    |> cast(attrs, [:price_usd])
    |> validate_required([:price_usd])
    |> validate_price()
    |> update_timestamp()
  end

  # Valida que el nombre de la moneda esté en mayúsculas y tenga entre 3 y 4 caracteres
  defp validate_currency_name(changeset) do
    changeset
    |> validate_format(:name, ~r/^[A-Z]{3,4}$/,
         message: "debe estar en mayúsculas y tener entre 3 y 4 letras")
  end

  # Valida que el precio no sea negativo
  defp validate_price(changeset) do
    changeset
    |> validate_number(:price_usd, greater_than_or_equal_to: 0.0,
         message: "no puede ser negativo")
  end

  # Agrega timestamps en la creación
  defp put_timestamps(changeset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    changeset
    |> put_change(:inserted_at, now)
    |> put_change(:updated_at, now)
  end

  # Actualiza el timestamp de modificación
  defp update_timestamp(changeset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    put_change(changeset, :updated_at, now)
  end
end
