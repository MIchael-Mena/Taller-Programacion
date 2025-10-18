defmodule Ledger.Repo.Migrations.CreateCurrencies do
  use Ecto.Migration

  def change do
    create table(:currencies) do
      add :name, :string, null: false
      add :price_usd, :float, null: false
      add :inserted_at, :naive_datetime, null: false
      add :updated_at, :naive_datetime, null: false
    end

    create unique_index(:currencies, [:name], name: :currencies_name_index)
  end
end
