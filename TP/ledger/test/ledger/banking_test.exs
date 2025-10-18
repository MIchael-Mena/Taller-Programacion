defmodule Ledger.BankingTest do
  use ExUnit.Case, async: true

  alias Ledger.Banking
  alias Ledger.Accounts
  alias Ledger.Currencies
  alias Ledger.Repo

  setup do
    # Limpiar la base de datos antes de cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create_account/1" do
    test "crea una cuenta válida" do
      # Crear usuario y moneda primero
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert account.user_id == user.id
      assert account.currency_id == currency.id
      assert Decimal.eq?(account.balance, Decimal.new("1000.0"))
      assert account.inserted_at
      assert account.updated_at
    end

    test "crea una cuenta con balance 0 por defecto" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      assert {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 0
      })

      assert Decimal.eq?(account.balance, Decimal.new("0"))
    end

    test "no permite crear cuenta sin user_id" do
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, changeset} = Banking.create_account(%{
        currency_id: currency.id,
        balance: 100.0
      })

      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite crear cuenta sin currency_id" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      assert {:error, changeset} = Banking.create_account(%{
        user_id: user.id,
        balance: 100.0
      })

      assert %{currency_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite crear cuenta con balance negativo" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, changeset} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: -100.0
      })

      assert %{balance: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "no permite crear cuenta con user_id inexistente" do
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, changeset} = Banking.create_account(%{
        user_id: 99999,
        currency_id: currency.id,
        balance: 100.0
      })

      assert %{user_id: ["El usuario especificado no existe"]} = errors_on(changeset)
    end

    test "no permite crear cuenta con currency_id inexistente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      assert {:error, changeset} = Banking.create_account(%{
        user_id: user.id,
        currency_id: 99999,
        balance: 100.0
      })

      assert %{currency_id: ["La moneda especificada no existe"]} = errors_on(changeset)
    end

    test "no permite crear cuenta duplicada (mismo usuario y moneda)" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      # Crear primera cuenta
      {:ok, _account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      # Intentar crear segunda cuenta con mismo usuario y moneda
      assert {:error, changeset} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 500.0
      })

      assert %{user_id: ["El usuario ya tiene una cuenta para esta moneda"]} = errors_on(changeset)
    end

    test "permite crear múltiples cuentas para el mismo usuario con diferentes monedas" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, eth} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      assert {:ok, account1} = Banking.create_account(%{
        user_id: user.id,
        currency_id: btc.id,
        balance: 1000.0
      })

      assert {:ok, account2} = Banking.create_account(%{
        user_id: user.id,
        currency_id: eth.id,
        balance: 500.0
      })

      assert account1.currency_id == btc.id
      assert account2.currency_id == eth.id
      assert account1.user_id == account2.user_id
    end

    test "permite crear cuentas para diferentes usuarios con la misma moneda" do
      {:ok, user1} = Accounts.create_user(%{username: "user1", birthdate: ~D[1990-01-01]})
      {:ok, user2} = Accounts.create_user(%{username: "user2", birthdate: ~D[1995-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:ok, account1} = Banking.create_account(%{
        user_id: user1.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert {:ok, account2} = Banking.create_account(%{
        user_id: user2.id,
        currency_id: currency.id,
        balance: 2000.0
      })

      assert account1.user_id == user1.id
      assert account2.user_id == user2.id
      assert account1.currency_id == account2.currency_id
    end
  end

  describe "get_account/1" do
    test "obtiene una cuenta existente por ID" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, created_account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      account = Banking.get_account(created_account.id)

      assert account.id == created_account.id
      assert account.user_id == user.id
      assert account.currency_id == currency.id
    end

    test "retorna nil para ID inexistente" do
      assert Banking.get_account(99999) == nil
    end
  end

  describe "get_account_by_user_and_currency/2" do
    test "obtiene una cuenta por usuario y moneda" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, created_account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      account = Banking.get_account_by_user_and_currency(user.id, currency.id)

      assert account.id == created_account.id
      assert account.user_id == user.id
      assert account.currency_id == currency.id
    end

    test "retorna nil si no existe cuenta para ese usuario y moneda" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert Banking.get_account_by_user_and_currency(user.id, currency.id) == nil
    end

    test "retorna nil para usuario inexistente" do
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert Banking.get_account_by_user_and_currency(99999, currency.id) == nil
    end

    test "retorna nil para moneda inexistente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      assert Banking.get_account_by_user_and_currency(user.id, 99999) == nil
    end
  end

  describe "list_user_accounts/1" do
    test "lista todas las cuentas de un usuario" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, eth} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})
      {:ok, usdt} = Currencies.create_currency(%{name: "USDT", price_usd: 1.0})

      {:ok, _} = Banking.create_account(%{user_id: user.id, currency_id: btc.id, balance: 100})
      {:ok, _} = Banking.create_account(%{user_id: user.id, currency_id: eth.id, balance: 200})
      {:ok, _} = Banking.create_account(%{user_id: user.id, currency_id: usdt.id, balance: 300})

      accounts = Banking.list_user_accounts(user.id)

      assert length(accounts) == 3
      assert Enum.all?(accounts, fn acc -> acc.user_id == user.id end)
    end

    test "retorna lista vacía para usuario sin cuentas" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      accounts = Banking.list_user_accounts(user.id)

      assert accounts == []
    end

    test "retorna lista vacía para usuario inexistente" do
      accounts = Banking.list_user_accounts(99999)

      assert accounts == []
    end
  end

  describe "list_accounts/0" do
    test "lista todas las cuentas" do
      {:ok, user1} = Accounts.create_user(%{username: "user1", birthdate: ~D[1990-01-01]})
      {:ok, user2} = Accounts.create_user(%{username: "user2", birthdate: ~D[1995-01-01]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, eth} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      {:ok, _} = Banking.create_account(%{user_id: user1.id, currency_id: btc.id, balance: 100})
      {:ok, _} = Banking.create_account(%{user_id: user1.id, currency_id: eth.id, balance: 200})
      {:ok, _} = Banking.create_account(%{user_id: user2.id, currency_id: btc.id, balance: 300})

      accounts = Banking.list_accounts()

      assert length(accounts) == 3
    end

    test "retorna lista vacía cuando no hay cuentas" do
      accounts = Banking.list_accounts()

      assert accounts == []
    end
  end

  describe "update_account_balance/2" do
    test "actualiza el balance correctamente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert {:ok, updated_account} = Banking.update_account_balance(account, %{balance: 2000.0})

      assert Decimal.eq?(updated_account.balance, Decimal.new("2000.0"))
      assert updated_account.id == account.id
    end

    test "permite actualizar balance a 0" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert {:ok, updated_account} = Banking.update_account_balance(account, %{balance: 0})

      assert Decimal.eq?(updated_account.balance, Decimal.new("0"))
    end

    test "no permite actualizar balance a negativo" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert {:error, changeset} = Banking.update_account_balance(account, %{balance: -500})

      assert %{balance: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end
  end

  describe "delete_account/1" do
    test "elimina una cuenta sin transacciones" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert {:ok, deleted_account} = Banking.delete_account(account)

      assert deleted_account.id == account.id
      assert Banking.get_account(account.id) == nil
    end
  end

  describe "account_exists?/2" do
    test "retorna true para cuenta existente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, _account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: 1000.0
      })

      assert Banking.account_exists?(user.id, currency.id) == true
    end

    test "retorna false para cuenta inexistente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert Banking.account_exists?(user.id, currency.id) == false
    end

    test "retorna false para usuario inexistente" do
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert Banking.account_exists?(99999, currency.id) == false
    end

    test "retorna false para moneda inexistente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      assert Banking.account_exists?(user.id, 99999) == false
    end
  end

  describe "open_account/3" do
    test "da de alta una cuenta con monto inicial" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:ok, account} = Banking.open_account(user.id, currency.id, 1000.0)

      assert account.user_id == user.id
      assert account.currency_id == currency.id
      assert Decimal.eq?(account.balance, Decimal.new("1000.0"))
    end

    test "da de alta cuenta con monto 0" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:ok, account} = Banking.open_account(user.id, currency.id, 0)

      assert Decimal.eq?(account.balance, Decimal.new("0"))
    end

    test "acepta monto como Decimal" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:ok, account} = Banking.open_account(user.id, currency.id, Decimal.new("500.75"))

      assert Decimal.eq?(account.balance, Decimal.new("500.75"))
    end

    test "acepta monto como string" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      # Crear cuenta con balance como string (será normalizado)
      assert {:ok, account} = Banking.create_account(%{
        user_id: user.id,
        currency_id: currency.id,
        balance: "1234.56"
      })

      assert Decimal.eq?(account.balance, Decimal.new("1234.56"))
    end

    test "no permite dar de alta cuenta con monto negativo" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, message} = Banking.open_account(user.id, currency.id, -100)

      assert message == "El monto debe ser mayor o igual a 0"
    end

    test "rechaza monto negativo como Decimal" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, message} = Banking.open_account(user.id, currency.id, Decimal.new("-50"))

      assert message == "El monto debe ser mayor o igual a 0"
    end

    test "no permite dar de alta cuenta para usuario inexistente" do
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, message} = Banking.open_account(99999, currency.id, 1000)

      assert message == "El usuario con ID 99999 no existe"
    end

    test "no permite dar de alta cuenta para moneda inexistente" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})

      assert {:error, message} = Banking.open_account(user.id, 99999, 1000)

      assert message == "La moneda con ID 99999 no existe"
    end

    test "no permite dar de alta cuenta duplicada" do
      {:ok, user} = Accounts.create_user(%{username: "test_user", birthdate: ~D[1990-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      # Primera cuenta
      {:ok, _} = Banking.open_account(user.id, currency.id, 1000)

      # Intento de segunda cuenta
      assert {:error, message} = Banking.open_account(user.id, currency.id, 500)

      assert message == "El usuario ya tiene una cuenta para esta moneda"
    end
  end

  # Helper para obtener errores del changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
