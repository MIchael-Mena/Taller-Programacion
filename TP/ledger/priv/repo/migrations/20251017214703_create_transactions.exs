defmodule Ledger.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :type, :string, null: false
      add :amount, :decimal, precision: 20, scale: 6, null: false
      add :amount_converted, :decimal, precision: 20, scale: 6
      add :timestamp, :utc_datetime, null: false, default: fragment("NOW()")

      # Foreign keys to accounts (nullable for account_from in alta_cuenta)
      add :account_from_id, references(:accounts, on_delete: :restrict)
      add :account_to_id, references(:accounts, on_delete: :restrict), null: false

      # Foreign keys to currencies (for query optimization and swap tracking)
      add :currency_from_id, references(:currencies, on_delete: :restrict)
      add :currency_to_id, references(:currencies, on_delete: :restrict)

      timestamps()
    end

    # Check constraint: type must be one of the valid values
    create constraint(:transactions, :valid_type,
             check: "type IN ('alta_cuenta', 'transferencia', 'swap')"
           )

    # Check constraint: amount must be positive
    create constraint(:transactions, :positive_amount, check: "amount > 0")

    # Indexes for performance
    create index(:transactions, [:account_from_id])
    create index(:transactions, [:account_to_id])
    create index(:transactions, [:timestamp])
    create index(:transactions, [:type])
  end
end
