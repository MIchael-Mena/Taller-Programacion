defmodule Ledger.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :currency_id, references(:currencies, on_delete: :restrict), null: false
      add :balance, :decimal, precision: 20, scale: 6, null: false, default: 0.0

      timestamps(type: :naive_datetime)
    end

    # Índice único: un usuario solo puede tener UNA cuenta por moneda
    create unique_index(:accounts, [:user_id, :currency_id], name: :accounts_user_currency_index)

    # Índices para mejorar performance de queries
    create index(:accounts, [:user_id])
    create index(:accounts, [:currency_id])
  end
end
