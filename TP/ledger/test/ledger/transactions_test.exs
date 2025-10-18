defmodule Ledger.TransactionsTest do
  use ExUnit.Case, async: true

  alias Ledger.Transactions
  alias Ledger.Accounts
  alias Ledger.Currencies
  alias Ledger.Banking
  alias Ledger.Repo

  setup do
    # Limpia la base de datos antes de cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "alta_cuenta/3" do
    setup do
      {:ok, user} = Accounts.create_user(%{username: "testuser", birthdate: ~D[2000-01-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      %{user: user, currency: currency}
    end

    test "crea cuenta con monto inicial válido", %{user: user, currency: currency} do
      amount = Decimal.new("100.50")

      assert {:ok, transaction} = Transactions.alta_cuenta(user.id, currency.id, amount)
      assert transaction.type == "alta_cuenta"
      assert Decimal.equal?(transaction.amount, amount)
      assert transaction.account_to_id != nil
      assert transaction.currency_to_id == currency.id
      assert is_nil(transaction.account_from_id)
      assert is_nil(transaction.price_origin)
      assert is_nil(transaction.price_destination)
      assert is_nil(transaction.conversion_rate)

      # Verificar que la cuenta fue creada con el balance correcto
      account = Banking.get_account(transaction.account_to_id)
      assert Decimal.equal?(account.balance, amount)
    end

    test "rechaza si usuario no existe", %{currency: currency} do
      assert {:error, reason} = Transactions.alta_cuenta(99999, currency.id, Decimal.new("100"))
      assert reason == "El usuario no existe"
    end

    test "rechaza si moneda no existe", %{user: user} do
      assert {:error, reason} = Transactions.alta_cuenta(user.id, 99999, Decimal.new("100"))
      assert reason == "La moneda no existe"
    end

    test "rechaza si usuario ya tiene cuenta en esa moneda", %{user: user, currency: currency} do
      # Primera alta_cuenta exitosa
      assert {:ok, _} = Transactions.alta_cuenta(user.id, currency.id, Decimal.new("100"))

      # Segunda alta_cuenta debe fallar
      assert {:error, reason} = Transactions.alta_cuenta(user.id, currency.id, Decimal.new("50"))
      assert reason == "El usuario ya tiene una cuenta en esta moneda"
    end

    test "rechaza monto 0", %{user: user, currency: currency} do
      assert {:error, reason} = Transactions.alta_cuenta(user.id, currency.id, Decimal.new("0"))
      assert reason == "El monto debe ser mayor a 0"
    end

    test "rechaza monto negativo", %{user: user, currency: currency} do
      assert {:error, reason} = Transactions.alta_cuenta(user.id, currency.id, Decimal.new("-10"))
      assert reason == "El monto debe ser mayor a 0"
    end

    test "acepta diferentes tipos numéricos", %{user: user, currency: currency} do
      # Integer
      assert {:ok, _} = Transactions.alta_cuenta(user.id, currency.id, 100)

      # Crear otra moneda para probar float
      {:ok, currency2} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})
      assert {:ok, _} = Transactions.alta_cuenta(user.id, currency2.id, 50.75)

      # String
      {:ok, currency3} = Currencies.create_currency(%{name: "ARS", price_usd: 0.0012})
      assert {:ok, _} = Transactions.alta_cuenta(user.id, currency3.id, "1000.50")
    end
  end

  describe "realizar_transferencia/4" do
    setup do
      {:ok, user1} = Accounts.create_user(%{username: "alice", birthdate: ~D[1995-03-15]})
      {:ok, user2} = Accounts.create_user(%{username: "bob", birthdate: ~D[1998-07-20]})
      {:ok, currency} = Currencies.create_currency(%{name: "USDT", price_usd: 1.0})

      # Crear cuentas para ambos usuarios
      {:ok, _} = Transactions.alta_cuenta(user1.id, currency.id, Decimal.new("1000"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, currency.id, Decimal.new("500"))

      %{user1: user1, user2: user2, currency: currency}
    end

    test "transfiere monto correctamente", %{user1: user1, user2: user2, currency: currency} do
      amount = Decimal.new("250.50")

      assert {:ok, transaction} =
               Transactions.realizar_transferencia(user1.id, user2.id, currency.id, amount)

      assert transaction.type == "transferencia"
      assert Decimal.equal?(transaction.amount, amount)
      assert transaction.account_from_id != nil
      assert transaction.account_to_id != nil
      assert transaction.currency_from_id == currency.id
      assert transaction.currency_to_id == currency.id

      # Verificar precios históricos
      assert Decimal.equal?(transaction.price_origin, Decimal.from_float(1.0))
      assert Decimal.equal?(transaction.price_destination, Decimal.from_float(1.0))
      assert Decimal.equal?(transaction.conversion_rate, Decimal.new("1.0"))

      # Verificar balances actualizados
      account1 = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: currency.id)
      account2 = Repo.get_by(Ledger.Account, user_id: user2.id, currency_id: currency.id)

      assert Decimal.equal?(account1.balance, Decimal.new("749.50"))
      assert Decimal.equal?(account2.balance, Decimal.new("750.50"))
    end

    test "rechaza si usuario origen no existe", %{user2: user2, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(99999, user2.id, currency.id, Decimal.new("100"))

      assert reason == "El usuario origen no existe"
    end

    test "rechaza si usuario destino no existe", %{user1: user1, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, 99999, currency.id, Decimal.new("100"))

      assert reason == "El usuario destino no existe"
    end

    test "rechaza si usuarios son iguales", %{user1: user1, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, user1.id, currency.id, Decimal.new("100"))

      assert reason == "No se puede transferir a la misma cuenta"
    end

    test "rechaza si moneda no existe", %{user1: user1, user2: user2} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, user2.id, 99999, Decimal.new("100"))

      assert reason == "La moneda no existe"
    end

    test "rechaza si usuario origen no tiene cuenta en esa moneda", %{
      user1: user1,
      user2: _user2,
      currency: currency
    } do
      {:ok, user3} = Accounts.create_user(%{username: "charlie", birthdate: ~D[2000-01-01]})
      {:ok, _} = Transactions.alta_cuenta(user3.id, currency.id, Decimal.new("100"))

      # user3 tiene cuenta, pero intentamos transferir desde user1 con moneda diferente
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, user3.id, btc.id, Decimal.new("1"))

      assert reason == "El usuario origen no tiene cuenta en esta moneda"
    end

    test "rechaza si usuario destino no tiene cuenta en esa moneda", %{
      user1: user1,
      user2: user2
    } do
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))

      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("1"))

      assert reason == "El usuario destino no tiene cuenta en esta moneda"
    end

    test "rechaza monto 0", %{user1: user1, user2: user2, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(user1.id, user2.id, currency.id, Decimal.new("0"))

      assert reason == "El monto debe ser mayor a 0"
    end

    test "rechaza monto negativo", %{user1: user1, user2: user2, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(
                 user1.id,
                 user2.id,
                 currency.id,
                 Decimal.new("-50")
               )

      assert reason == "El monto debe ser mayor a 0"
    end

    test "rechaza si balance insuficiente", %{user1: user1, user2: user2, currency: currency} do
      assert {:error, reason} =
               Transactions.realizar_transferencia(
                 user1.id,
                 user2.id,
                 currency.id,
                 Decimal.new("2000")
               )

      assert reason == "Balance insuficiente en la cuenta origen"
    end

    test "permite transferir todo el balance", %{user1: user1, user2: user2, currency: currency} do
      assert {:ok, _transaction} =
               Transactions.realizar_transferencia(
                 user1.id,
                 user2.id,
                 currency.id,
                 Decimal.new("1000")
               )

      account1 = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: currency.id)
      assert Decimal.equal?(account1.balance, Decimal.new("0"))
    end
  end

  describe "realizar_swap/4" do
    setup do
      {:ok, user} = Accounts.create_user(%{username: "swapper", birthdate: ~D[1990-05-10]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, eth} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      # Crear cuentas para ambas monedas
      {:ok, _} = Transactions.alta_cuenta(user.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user.id, eth.id, Decimal.new("100"))

      %{user: user, btc: btc, eth: eth}
    end

    test "realiza swap correctamente con cálculo de conversión", %{
      user: user,
      btc: btc,
      eth: eth
    } do
      # Swap 1 BTC → ETH
      # Esperado: (1 × 50000) / 3000 = 16.666666... ETH
      amount = Decimal.new("1")

      assert {:ok, transaction} =
               Transactions.realizar_swap(user.id, btc.id, eth.id, amount)

      assert transaction.type == "swap"
      assert Decimal.equal?(transaction.amount, amount)

      # Verificar precios históricos
      assert Decimal.equal?(transaction.price_origin, Decimal.from_float(50000.0))
      assert Decimal.equal?(transaction.price_destination, Decimal.from_float(3000.0))

      # Verificar conversion_rate
      expected_rate = Decimal.div(Decimal.from_float(50000.0), Decimal.from_float(3000.0))
      assert Decimal.equal?(transaction.conversion_rate, expected_rate)

      # Verificar amount_converted
      expected_converted = Decimal.div(Decimal.from_float(50000.0), Decimal.from_float(3000.0))
      assert Decimal.equal?(transaction.amount_converted, expected_converted)

      # Verificar balances
      btc_account = Repo.get_by(Ledger.Account, user_id: user.id, currency_id: btc.id)
      eth_account = Repo.get_by(Ledger.Account, user_id: user.id, currency_id: eth.id)

      assert Decimal.equal?(btc_account.balance, Decimal.new("9"))
      # 100 + 16.666666... = 116.666666... (comparación con redondeo a 6 decimales)
      expected_balance = Decimal.add(Decimal.new("100"), expected_converted)
      assert Decimal.compare(
        Decimal.round(eth_account.balance, 6),
        Decimal.round(expected_balance, 6)
      ) == :eq
    end

    test "rechaza si usuario no existe", %{btc: btc, eth: eth} do
      assert {:error, reason} =
               Transactions.realizar_swap(99999, btc.id, eth.id, Decimal.new("1"))

      assert reason == "El usuario no existe"
    end

    test "rechaza si moneda origen no existe", %{user: user, eth: eth} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, 99999, eth.id, Decimal.new("1"))

      assert reason == "La moneda origen no existe"
    end

    test "rechaza si moneda destino no existe", %{user: user, btc: btc} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, 99999, Decimal.new("1"))

      assert reason == "La moneda destino no existe"
    end

    test "rechaza swap a la misma moneda", %{user: user, btc: btc} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, btc.id, Decimal.new("1"))

      assert reason == "No se puede hacer swap a la misma moneda"
    end

    test "rechaza si usuario no tiene cuenta en moneda origen", %{user: user, btc: _btc} do
      {:ok, ars} = Currencies.create_currency(%{name: "ARS", price_usd: 0.0012})
      {:ok, _} = Transactions.alta_cuenta(user.id, ars.id, Decimal.new("1000"))

      {:ok, usdt} = Currencies.create_currency(%{name: "USDT", price_usd: 1.0})

      assert {:error, reason} =
               Transactions.realizar_swap(user.id, usdt.id, ars.id, Decimal.new("100"))

      assert reason == "El usuario no tiene cuenta en la moneda origen"
    end

    test "rechaza si usuario no tiene cuenta en moneda destino", %{user: user, btc: btc} do
      {:ok, usdt} = Currencies.create_currency(%{name: "USDT", price_usd: 1.0})

      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, usdt.id, Decimal.new("1"))

      assert reason == "El usuario no tiene cuenta en la moneda destino"
    end

    test "rechaza monto 0", %{user: user, btc: btc, eth: eth} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, eth.id, Decimal.new("0"))

      assert reason == "El monto debe ser mayor a 0"
    end

    test "rechaza monto negativo", %{user: user, btc: btc, eth: eth} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, eth.id, Decimal.new("-1"))

      assert reason == "El monto debe ser mayor a 0"
    end

    test "rechaza si balance insuficiente", %{user: user, btc: btc, eth: eth} do
      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, eth.id, Decimal.new("100"))

      assert reason == "Balance insuficiente en la cuenta origen"
    end

    test "rechaza swap a moneda con precio 0 (división por cero)", %{user: user, btc: btc} do
      {:ok, dead} = Currencies.create_currency(%{name: "DEAD", price_usd: 0.0})
      {:ok, _} = Transactions.alta_cuenta(user.id, dead.id, Decimal.new("1000"))

      assert {:error, reason} =
               Transactions.realizar_swap(user.id, btc.id, dead.id, Decimal.new("1"))

      assert reason == "No se puede convertir a una moneda sin valor (precio = $0)"
    end

    test "permite swap desde moneda con precio 0 (resultado = 0)", %{user: user, eth: eth} do
      {:ok, dead} = Currencies.create_currency(%{name: "DEAD", price_usd: 0.0})
      {:ok, _} = Transactions.alta_cuenta(user.id, dead.id, Decimal.new("1000"))

      # Swap desde DEAD → ETH debería resultar en 0 ETH
      assert {:ok, transaction} =
               Transactions.realizar_swap(user.id, dead.id, eth.id, Decimal.new("1000"))

      assert Decimal.equal?(transaction.amount_converted, Decimal.new("0"))

      # Verificar balances
      dead_account = Repo.get_by(Ledger.Account, user_id: user.id, currency_id: dead.id)
      eth_account = Repo.get_by(Ledger.Account, user_id: user.id, currency_id: eth.id)

      assert Decimal.equal?(dead_account.balance, Decimal.new("0"))
      assert Decimal.equal?(eth_account.balance, Decimal.new("100"))
    end

    test "permite swap de todo el balance", %{user: user, btc: btc, eth: eth} do
      assert {:ok, _transaction} =
               Transactions.realizar_swap(user.id, btc.id, eth.id, Decimal.new("10"))

      btc_account = Repo.get_by(Ledger.Account, user_id: user.id, currency_id: btc.id)
      assert Decimal.equal?(btc_account.balance, Decimal.new("0"))
    end
  end

  describe "deshacer_transaccion/1" do
    setup do
      {:ok, user1} = Accounts.create_user(%{username: "undoer1", birthdate: ~D[1992-08-15]})
      {:ok, user2} = Accounts.create_user(%{username: "undoer2", birthdate: ~D[1995-03-20]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})
      {:ok, eth} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      %{user1: user1, user2: user2, btc: btc, eth: eth}
    end

    test "deshace alta_cuenta poniendo balance en 0", %{user1: user1, btc: btc} do
      # Crear cuenta
      {:ok, transaction} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("5"))
      account_id = transaction.account_to_id

      # Deshacer
      assert {:ok, _result} = Transactions.deshacer_transaccion(transaction.id)

      # Verificar que la cuenta sigue existiendo pero con balance 0
      account = Banking.get_account(account_id)
      refute is_nil(account)
      assert Decimal.equal?(account.balance, Decimal.new("0"))
    end

    test "rechaza deshacer alta_cuenta si balance cambió", %{user1: user1, user2: user2, btc: btc} do
      # User1 crea cuenta BTC
      {:ok, tx1} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))

      # User2 crea cuenta BTC y transfiere a user1
      {:ok, _tx2} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("5"))
      {:ok, _tx3} = Transactions.realizar_transferencia(user2.id, user1.id, btc.id, Decimal.new("2"))

      # Ahora user1 tiene 12 BTC (no los 10 originales)
      # Intentar deshacer tx1 debería fallar
      assert {:error, reason} = Transactions.deshacer_transaccion(tx1.id)
      assert reason == "Solo se puede deshacer la última transacción de lo/los usuarios asociados"
    end

    test "deshace transferencia correctamente", %{user1: user1, user2: user2, btc: btc} do
      # Crear cuentas
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("5"))

      # Transferir
      {:ok, transaction} =
        Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("3"))

      # Verificar balances después de transferencia
      account1 = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: btc.id)
      account2 = Repo.get_by(Ledger.Account, user_id: user2.id, currency_id: btc.id)
      assert Decimal.equal?(account1.balance, Decimal.new("7"))
      assert Decimal.equal?(account2.balance, Decimal.new("8"))

      # Deshacer
      assert {:ok, reverse_transaction} = Transactions.deshacer_transaccion(transaction.id)

      # Verificar que es una transferencia inversa
      assert reverse_transaction.type == "transferencia"
      assert Decimal.equal?(reverse_transaction.amount, Decimal.new("3"))
      assert reverse_transaction.account_from_id == transaction.account_to_id
      assert reverse_transaction.account_to_id == transaction.account_from_id

      # Verificar balances restaurados
      account1 = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: btc.id)
      account2 = Repo.get_by(Ledger.Account, user_id: user2.id, currency_id: btc.id)
      assert Decimal.equal?(account1.balance, Decimal.new("10"))
      assert Decimal.equal?(account2.balance, Decimal.new("5"))
    end

    test "rechaza deshacer transferencia si no es la última", %{
      user1: user1,
      user2: user2,
      btc: btc
    } do
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("5"))

      # Primera transferencia
      {:ok, tx1} = Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("2"))

      # Segunda transferencia
      {:ok, _tx2} = Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("1"))

      # Intentar deshacer la primera debería fallar
      assert {:error, reason} = Transactions.deshacer_transaccion(tx1.id)
      assert reason == "Solo se puede deshacer la última transacción de lo/los usuarios asociados"
    end

    test "rechaza deshacer transferencia si balance destino insuficiente", %{
      user1: user1,
      user2: user2,
      btc: btc,
      eth: eth
    } do
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("5"))

      # user2 también tiene cuenta ETH
      {:ok, _} = Transactions.alta_cuenta(user2.id, eth.id, Decimal.new("10"))

      # user1 transfiere a user2
      {:ok, tx} = Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("3"))

      # user2 hace swap de sus BTC a ETH (gasta los BTC)
      {:ok, _} = Transactions.realizar_swap(user2.id, btc.id, eth.id, Decimal.new("8"))

      # Ahora user2 tiene menos de 3 BTC, no se puede deshacer
      assert {:error, reason} = Transactions.deshacer_transaccion(tx.id)
      assert reason == "Solo se puede deshacer la última transacción de lo/los usuarios asociados"
    end

    test "deshace swap usando precios históricos", %{user1: user1, btc: btc, eth: eth} do
      # Crear cuentas
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user1.id, eth.id, Decimal.new("100"))

      # Realizar swap: 1 BTC → ETH
      {:ok, transaction} = Transactions.realizar_swap(user1.id, btc.id, eth.id, Decimal.new("1"))

      # amount_converted = (1 × 50000) / 3000 = 16.666666... ETH
      expected_eth = Decimal.div(Decimal.from_float(50000.0), Decimal.from_float(3000.0))

      # Verificar balances después del swap
      btc_account = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: btc.id)
      eth_account = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: eth.id)
      assert Decimal.equal?(btc_account.balance, Decimal.new("9"))
      expected_balance = Decimal.add(Decimal.new("100"), expected_eth)
      assert Decimal.compare(
        Decimal.round(eth_account.balance, 6),
        Decimal.round(expected_balance, 6)
      ) == :eq

      # Cambiar precios de las monedas (simular cambio de mercado)
      Currencies.update_currency(btc, %{price_usd: 60000.0})
      Currencies.update_currency(eth, %{price_usd: 4000.0})

      # Deshacer swap (debe usar precios históricos, NO los actuales)
      assert {:ok, reverse_transaction} = Transactions.deshacer_transaccion(transaction.id)

      # Verificar que usó precios históricos
      assert Decimal.equal?(reverse_transaction.price_origin, Decimal.from_float(3000.0))
      assert Decimal.equal?(reverse_transaction.price_destination, Decimal.from_float(50000.0))

      # amount_reverted = (16.666666... × 3000) / 50000 ≈ 1.0 BTC (con redondeo)
      expected_btc_back =
        expected_eth
        |> Decimal.mult(Decimal.from_float(3000.0))
        |> Decimal.div(Decimal.from_float(50000.0))

      # Comparar con tolerancia de 6 decimales
      assert Decimal.compare(
        Decimal.round(reverse_transaction.amount_converted, 6),
        Decimal.round(expected_btc_back, 6)
      ) == :eq

      # Verificar balances restaurados exactamente
      btc_account = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: btc.id)
      eth_account = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: eth.id)
      assert Decimal.equal?(btc_account.balance, Decimal.new("10"))
      assert Decimal.equal?(eth_account.balance, Decimal.new("100"))
    end

    test "rechaza deshacer swap si no es la última transacción", %{user1: user1, btc: btc, eth: eth} do
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user1.id, eth.id, Decimal.new("100"))

      # Primer swap
      {:ok, tx1} = Transactions.realizar_swap(user1.id, btc.id, eth.id, Decimal.new("1"))

      # Segundo swap
      {:ok, _tx2} = Transactions.realizar_swap(user1.id, btc.id, eth.id, Decimal.new("2"))

      # Intentar deshacer el primero debería fallar
      assert {:error, reason} = Transactions.deshacer_transaccion(tx1.id)
      assert reason == "Solo se puede deshacer la última transacción de lo/los usuarios asociados"
    end

    test "rechaza deshacer swap si balance insuficiente", %{user1: user1, btc: btc, eth: eth} do
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user1.id, eth.id, Decimal.new("100"))

      # Hacer swap: BTC → ETH
      {:ok, tx} = Transactions.realizar_swap(user1.id, btc.id, eth.id, Decimal.new("5"))

      # Manualmente reducir balance de ETH (simular gasto externo - en realidad no debería pasar)
      eth_account = Repo.get_by(Ledger.Account, user_id: user1.id, currency_id: eth.id)

      eth_account
      |> Ledger.Account.changeset(%{balance: Decimal.new("10")})
      |> Repo.update!()

      # Intentar deshacer debería fallar por balance insuficiente
      assert {:error, reason} = Transactions.deshacer_transaccion(tx.id)
      assert reason == "Balance insuficiente para deshacer el swap"
    end

    test "rechaza deshacer transacción inexistente" do
      assert {:error, reason} = Transactions.deshacer_transaccion(99999)
      assert reason == "La transacción no existe"
    end
  end

  describe "get_transaction/1" do
    setup do
      {:ok, user} = Accounts.create_user(%{username: "getter", birthdate: ~D[1988-12-01]})
      {:ok, currency} = Currencies.create_currency(%{name: "USDT", price_usd: 1.0})
      {:ok, transaction} = Transactions.alta_cuenta(user.id, currency.id, Decimal.new("500"))

      %{transaction: transaction}
    end

    test "obtiene una transacción existente con preloads", %{transaction: transaction} do
      fetched = Transactions.get_transaction(transaction.id)

      assert fetched.id == transaction.id
      assert fetched.type == "alta_cuenta"
      assert Ecto.assoc_loaded?(fetched.account_to)
      assert Ecto.assoc_loaded?(fetched.currency_to)
    end

    test "retorna nil para ID inexistente" do
      assert is_nil(Transactions.get_transaction(99999))
    end
  end

  describe "list_transactions/0" do
    setup do
      {:ok, user1} = Accounts.create_user(%{username: "lister1", birthdate: ~D[1990-01-01]})
      {:ok, user2} = Accounts.create_user(%{username: "lister2", birthdate: ~D[1992-05-15]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("5"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("3"))
      {:ok, _} = Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("1"))

      %{user1: user1, user2: user2, btc: btc}
    end

    test "lista todas las transacciones" do
      transactions = Transactions.list_transactions()

      assert length(transactions) == 3
      assert Enum.all?(transactions, &Ecto.assoc_loaded?(&1.account_to))
    end

    test "ordena por timestamp descendente" do
      transactions = Transactions.list_transactions()

      # La transferencia debería ser la primera (más reciente)
      assert hd(transactions).type == "transferencia"
    end

    test "retorna lista vacía cuando no hay transacciones" do
      # Limpiar todas las transacciones
      Repo.delete_all(Ledger.Transaction)

      assert Transactions.list_transactions() == []
    end
  end

  describe "list_user_transactions/1" do
    setup do
      {:ok, user1} = Accounts.create_user(%{username: "txuser1", birthdate: ~D[1985-03-10]})
      {:ok, user2} = Accounts.create_user(%{username: "txuser2", birthdate: ~D[1990-07-25]})
      {:ok, user3} = Accounts.create_user(%{username: "txuser3", birthdate: ~D[1995-11-30]})
      {:ok, btc} = Currencies.create_currency(%{name: "BTC", price_usd: 50000.0})

      # user1 y user2 tienen transacciones
      {:ok, _} = Transactions.alta_cuenta(user1.id, btc.id, Decimal.new("10"))
      {:ok, _} = Transactions.alta_cuenta(user2.id, btc.id, Decimal.new("5"))
      {:ok, _} = Transactions.realizar_transferencia(user1.id, user2.id, btc.id, Decimal.new("2"))

      # user3 no tiene transacciones
      %{user1: user1, user2: user2, user3: user3}
    end

    test "lista todas las transacciones de un usuario", %{user1: user1} do
      transactions = Transactions.list_user_transactions(user1.id)

      # user1 tiene: 1 alta_cuenta + 1 transferencia = 2 transacciones
      assert length(transactions) == 2
    end

    test "incluye transacciones donde el usuario es origen o destino", %{user2: user2} do
      transactions = Transactions.list_user_transactions(user2.id)

      # user2 tiene: 1 alta_cuenta + 1 transferencia (como destino) = 2 transacciones
      assert length(transactions) == 2
    end

    test "retorna lista vacía para usuario sin transacciones", %{user3: user3} do
      transactions = Transactions.list_user_transactions(user3.id)

      assert transactions == []
    end

    test "ordena por timestamp descendente", %{user1: user1} do
      transactions = Transactions.list_user_transactions(user1.id)

      # La transferencia debería ser la primera
      assert hd(transactions).type == "transferencia"
    end
  end
end
