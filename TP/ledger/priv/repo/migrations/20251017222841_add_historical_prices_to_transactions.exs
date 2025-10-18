defmodule Ledger.Repo.Migrations.AddHistoricalPricesToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      # Precio de la moneda origen al momento de la transacción (en USD)
      add :price_origin, :decimal, precision: 20, scale: 6

      # Precio de la moneda destino al momento de la transacción (en USD)
      add :price_destination, :decimal, precision: 20, scale: 6

      # Ratio de conversión calculado (price_origin / price_destination)
      # Este campo es redundante pero facilita consultas y auditoría
      add :conversion_rate, :decimal, precision: 20, scale: 6
    end
  end
end
