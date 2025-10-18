defmodule Ledger.Transactions do
  @moduledoc """
  Context para gestión de transacciones financieras.

  Maneja tres tipos de transacciones:
  - `alta_cuenta`: Crear una cuenta con balance inicial
  - `transferencia`: Transferir monto entre usuarios (misma moneda)
  - `swap`: Convertir monto entre monedas (mismo usuario)

  Todas las transacciones son inmutables y funcionan como audit trail.
  Los precios históricos se guardan para reproducir swaps exactamente.
  """

  import Ecto.Query
  alias Ledger.Repo
  alias Ledger.Transaction
  alias Ledger.Account
  alias Ledger.Currency
  alias Ledger.User

  @doc """
  Crea una cuenta para un usuario en una moneda específica con un balance inicial.

  ## Parámetros
  - `user_id`: ID del usuario
  - `currency_id`: ID de la moneda
  - `amount`: Monto inicial (debe ser > 0)

  ## Retorna
  - `{:ok, transaction}` si la operación fue exitosa
  - `{:error, reason}` si hubo un error

  ## Ejemplos

      iex> alta_cuenta(1, 2, Decimal.new("1000.50"))
      {:ok, %Transaction{type: "alta_cuenta", amount: #Decimal<1000.50>, ...}}

      iex> alta_cuenta(999, 1, Decimal.new("100"))
      {:error, "El usuario no existe"}

  ## Validaciones
  - Usuario debe existir
  - Moneda debe existir
  - Usuario NO debe tener ya una cuenta en esa moneda
  - Monto debe ser > 0
  """
  def alta_cuenta(user_id, currency_id, amount) do
    Repo.transaction(fn ->
      # Validar que usuario existe
      user = Repo.get(User, user_id)

      if is_nil(user) do
        Repo.rollback("El usuario no existe")
      end

      # Validar que moneda existe
      currency = Repo.get(Currency, currency_id)

      if is_nil(currency) do
        Repo.rollback("La moneda no existe")
      end

      # Validar que usuario NO tiene cuenta en esa moneda
      existing_account =
        Repo.get_by(Account, user_id: user_id, currency_id: currency_id)

      if not is_nil(existing_account) do
        Repo.rollback("El usuario ya tiene una cuenta en esta moneda")
      end

      # Convertir amount a Decimal si es necesario
      amount_decimal = ensure_decimal(amount)

      # Validar monto > 0
      if Decimal.compare(amount_decimal, Decimal.new("0")) != :gt do
        Repo.rollback("El monto debe ser mayor a 0")
      end

      # Crear la cuenta
      account_result =
        %Account{}
        |> Account.changeset(%{
          user_id: user_id,
          currency_id: currency_id,
          balance: amount_decimal
        })
        |> Repo.insert()

      account =
        case account_result do
          {:ok, acc} -> acc
          {:error, changeset} -> Repo.rollback(changeset)
        end

      # Registrar transacción (sin precios históricos para alta_cuenta)
      transaction_result =
        %Transaction{}
        |> Transaction.changeset(%{
          type: "alta_cuenta",
          amount: amount_decimal,
          account_to_id: account.id,
          currency_to_id: currency_id,
          # Sin precios históricos para alta_cuenta (no hay conversión)
          price_origin: nil,
          price_destination: nil,
          conversion_rate: nil
        })
        |> Repo.insert()

      case transaction_result do
        {:ok, transaction} -> transaction
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Transfiere un monto entre dos usuarios en la misma moneda.

  ## Parámetros
  - `user_from_id`: ID del usuario origen
  - `user_to_id`: ID del usuario destino
  - `currency_id`: ID de la moneda
  - `amount`: Monto a transferir

  ## Retorna
  - `{:ok, transaction}` si la transferencia fue exitosa
  - `{:error, reason}` si hubo un error

  ## Validaciones
  - Usuarios origen y destino deben existir
  - Usuarios deben ser diferentes
  - Moneda debe existir
  - Ambos usuarios deben tener cuenta en esa moneda
  - Usuario origen debe tener balance suficiente
  - Monto debe ser > 0
  """
  def realizar_transferencia(user_from_id, user_to_id, currency_id, amount) do
    Repo.transaction(fn ->
      # Validar que usuarios existen y son diferentes
      user_from = Repo.get(User, user_from_id)
      user_to = Repo.get(User, user_to_id)

      if is_nil(user_from) do
        Repo.rollback("El usuario origen no existe")
      end

      if is_nil(user_to) do
        Repo.rollback("El usuario destino no existe")
      end

      if user_from_id == user_to_id do
        Repo.rollback("No se puede transferir a la misma cuenta")
      end

      # Validar que moneda existe
      currency = Repo.get(Currency, currency_id)

      if is_nil(currency) do
        Repo.rollback("La moneda no existe")
      end

      # Obtener cuentas de origen y destino
      account_from =
        Repo.get_by(Account, user_id: user_from_id, currency_id: currency_id)

      account_to =
        Repo.get_by(Account, user_id: user_to_id, currency_id: currency_id)

      if is_nil(account_from) do
        Repo.rollback("El usuario origen no tiene cuenta en esta moneda")
      end

      if is_nil(account_to) do
        Repo.rollback("El usuario destino no tiene cuenta en esta moneda")
      end

      # Convertir amount a Decimal
      amount_decimal = ensure_decimal(amount)

      # Validar monto > 0
      if Decimal.compare(amount_decimal, Decimal.new("0")) != :gt do
        Repo.rollback("El monto debe ser mayor a 0")
      end

      # Validar balance suficiente
      if Decimal.compare(account_from.balance, amount_decimal) == :lt do
        Repo.rollback("Balance insuficiente en la cuenta origen")
      end

      # Actualizar balances
      new_balance_from = Decimal.sub(account_from.balance, amount_decimal)
      new_balance_to = Decimal.add(account_to.balance, amount_decimal)

      account_from
      |> Account.changeset(%{balance: new_balance_from})
      |> Repo.update!()

      account_to
      |> Account.changeset(%{balance: new_balance_to})
      |> Repo.update!()

      # Obtener precio actual de la moneda para registro histórico
      price_usd = Decimal.from_float(currency.price_usd)

      # Registrar transacción con precios históricos
      # Para transferencia, price_origin = price_destination (misma moneda)
      transaction_result =
        %Transaction{}
        |> Transaction.changeset(%{
          type: "transferencia",
          amount: amount_decimal,
          account_from_id: account_from.id,
          account_to_id: account_to.id,
          currency_from_id: currency_id,
          currency_to_id: currency_id,
          price_origin: price_usd,
          price_destination: price_usd,
          conversion_rate: Decimal.new("1.0")
        })
        |> Repo.insert()

      case transaction_result do
        {:ok, transaction} -> transaction
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Realiza un swap (conversión) entre dos monedas del mismo usuario.

  ## Parámetros
  - `user_id`: ID del usuario
  - `currency_from_id`: ID de la moneda origen
  - `currency_to_id`: ID de la moneda destino
  - `amount`: Monto en moneda origen

  ## Fórmula de conversión
  ```
  amount_to = (amount_from × price_from) / price_to
  ```

  ## Retorna
  - `{:ok, transaction}` si el swap fue exitoso
  - `{:error, reason}` si hubo un error

  ## Validaciones
  - Usuario debe existir
  - Monedas origen y destino deben existir y ser diferentes
  - Usuario debe tener cuenta en ambas monedas
  - Monto debe ser > 0
  - Balance origen debe ser suficiente
  - Precio de moneda destino no puede ser 0 (división por cero)
  """
  def realizar_swap(user_id, currency_from_id, currency_to_id, amount) do
    Repo.transaction(fn ->
      # Validar que usuario existe
      user = Repo.get(User, user_id)

      if is_nil(user) do
        Repo.rollback("El usuario no existe")
      end

      # Validar que monedas existen
      currency_from = Repo.get(Currency, currency_from_id)
      currency_to = Repo.get(Currency, currency_to_id)

      if is_nil(currency_from) do
        Repo.rollback("La moneda origen no existe")
      end

      if is_nil(currency_to) do
        Repo.rollback("La moneda destino no existe")
      end

      # Validar que monedas son diferentes
      if currency_from_id == currency_to_id do
        Repo.rollback("No se puede hacer swap a la misma moneda")
      end

      # Obtener cuentas
      account_from =
        Repo.get_by(Account, user_id: user_id, currency_id: currency_from_id)

      account_to =
        Repo.get_by(Account, user_id: user_id, currency_id: currency_to_id)

      if is_nil(account_from) do
        Repo.rollback("El usuario no tiene cuenta en la moneda origen")
      end

      if is_nil(account_to) do
        Repo.rollback("El usuario no tiene cuenta en la moneda destino")
      end

      # Convertir amount a Decimal
      amount_decimal = ensure_decimal(amount)

      # Validar monto > 0
      if Decimal.compare(amount_decimal, Decimal.new("0")) != :gt do
        Repo.rollback("El monto debe ser mayor a 0")
      end

      # Validar balance suficiente
      if Decimal.compare(account_from.balance, amount_decimal) == :lt do
        Repo.rollback("Balance insuficiente en la cuenta origen")
      end

      # Convertir precios a Decimal
      price_from = Decimal.from_float(currency_from.price_usd)
      price_to = Decimal.from_float(currency_to.price_usd)

      # CRÍTICO: Validar que precio destino no es 0 (división por cero)
      if Decimal.compare(price_to, Decimal.new("0")) == :eq do
        Repo.rollback(
          "No se puede convertir a una moneda sin valor (precio = $0)"
        )
      end

      # Calcular monto destino con precios históricos
      # amount_to = (amount_from × price_from) / price_to
      amount_converted =
        amount_decimal
        |> Decimal.mult(price_from)
        |> Decimal.div(price_to)

      # Calcular conversion_rate para auditoría
      conversion_rate = Decimal.div(price_from, price_to)

      # Actualizar balances
      new_balance_from = Decimal.sub(account_from.balance, amount_decimal)
      new_balance_to = Decimal.add(account_to.balance, amount_converted)

      account_from
      |> Account.changeset(%{balance: new_balance_from})
      |> Repo.update!()

      account_to
      |> Account.changeset(%{balance: new_balance_to})
      |> Repo.update!()

      # Registrar transacción con precios históricos
      transaction_result =
        %Transaction{}
        |> Transaction.changeset(%{
          type: "swap",
          amount: amount_decimal,
          amount_converted: amount_converted,
          account_from_id: account_from.id,
          account_to_id: account_to.id,
          currency_from_id: currency_from_id,
          currency_to_id: currency_to_id,
          price_origin: price_from,
          price_destination: price_to,
          conversion_rate: conversion_rate
        })
        |> Repo.insert()

      case transaction_result do
        {:ok, transaction} -> transaction
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deshace una transacción creando una transacción inversa.

  ## Regla Principal
  Solo se puede deshacer una transacción si es la última de lo/los usuarios asociados.

  ## Comportamiento por tipo
  - **alta_cuenta**: Marca la cuenta como cerrada (balance = 0) o la elimina
  - **transferencia**: Crea transferencia inversa (destino → origen, mismo monto)
  - **swap**: Crea swap inverso usando **precios históricos** de la transacción original

  ## Importante
  Al deshacer un swap, se usan los precios históricos guardados para reproducir
  exactamente la operación inversa.

  ## Retorna
  - `{:ok, reverse_transaction}` si se deshizo correctamente
  - `{:error, reason}` si no se pudo deshacer
  """
  def deshacer_transaccion(transaction_id) do
    Repo.transaction(fn ->
      # Obtener transacción original
      transaction =
        Repo.get(Transaction, transaction_id)
        |> Repo.preload([:account_from, :account_to])

      if is_nil(transaction) do
        Repo.rollback("La transacción no existe")
      end

      # Validar que es la última transacción de los usuarios involucrados
      unless is_last_transaction?(transaction) do
        Repo.rollback(
          "Solo se puede deshacer la última transacción de lo/los usuarios asociados"
        )
      end

      # Deshacer según tipo
      case transaction.type do
        "alta_cuenta" -> undo_alta_cuenta(transaction)
        "transferencia" -> undo_transferencia(transaction)
        "swap" -> undo_swap(transaction)
      end
    end)
  end

  # Validar si una transacción es la última de todos los usuarios involucrados
  defp is_last_transaction?(transaction) do
    case transaction.type do
      "alta_cuenta" ->
        is_last_for_account?(transaction.account_to_id, transaction.id)

      "transferencia" ->
        is_last_for_account?(transaction.account_from_id, transaction.id) and
          is_last_for_account?(transaction.account_to_id, transaction.id)

      "swap" ->
        is_last_for_account?(transaction.account_from_id, transaction.id) and
          is_last_for_account?(transaction.account_to_id, transaction.id)
    end
  end

  defp is_last_for_account?(account_id, transaction_id) do
    # Obtener la última transacción de esta cuenta
    last_transaction =
      from(t in Transaction,
        where:
          t.account_from_id == ^account_id or t.account_to_id == ^account_id,
        order_by: [desc: t.timestamp, desc: t.id],
        limit: 1
      )
      |> Repo.one()

    last_transaction.id == transaction_id
  end

  # Deshacer alta_cuenta: Poner balance en 0 (no eliminar por constraints)
  defp undo_alta_cuenta(transaction) do
    account = transaction.account_to

    # Validar que el balance actual sea igual al monto original
    if Decimal.compare(account.balance, transaction.amount) != :eq do
      Repo.rollback(
        "No se puede deshacer: el balance de la cuenta ha cambiado"
      )
    end

    # Poner balance en 0 en lugar de eliminar (la cuenta tiene FK desde transaction)
    account
    |> Ledger.Account.changeset(%{balance: Decimal.new("0")})
    |> Repo.update!()

    # Retornar la transacción original actualizada como confirmación
    transaction
  end

  # Deshacer transferencia: Crear transferencia inversa
  defp undo_transferencia(transaction) do
    account_from = transaction.account_from
    account_to = transaction.account_to

    # Validar que cuenta destino tiene balance suficiente
    if Decimal.compare(account_to.balance, transaction.amount) == :lt do
      Repo.rollback("Balance insuficiente para deshacer la transferencia")
    end

    # Revertir balances
    new_balance_from = Decimal.add(account_from.balance, transaction.amount)
    new_balance_to = Decimal.sub(account_to.balance, transaction.amount)

    account_from
    |> Account.changeset(%{balance: new_balance_from})
    |> Repo.update!()

    account_to
    |> Account.changeset(%{balance: new_balance_to})
    |> Repo.update!()

    # Crear transacción inversa con precios históricos originales
    %Transaction{}
    |> Transaction.changeset(%{
      type: "transferencia",
      amount: transaction.amount,
      account_from_id: account_to.id,
      account_to_id: account_from.id,
      currency_from_id: transaction.currency_to_id,
      currency_to_id: transaction.currency_from_id,
      price_origin: transaction.price_destination,
      price_destination: transaction.price_origin,
      conversion_rate: transaction.conversion_rate
    })
    |> Repo.insert!()
  end

  # Deshacer swap: Crear swap inverso usando precios históricos
  defp undo_swap(transaction) do
    account_from = transaction.account_from
    account_to = transaction.account_to

    # Validar que cuenta destino tiene balance suficiente
    if Decimal.compare(account_to.balance, transaction.amount_converted) ==
         :lt do
      Repo.rollback("Balance insuficiente para deshacer el swap")
    end

    # Calcular swap inverso usando precios históricos originales
    # amount_original = (amount_converted × price_to) / price_from
    amount_reverted =
      transaction.amount_converted
      |> Decimal.mult(transaction.price_destination)
      |> Decimal.div(transaction.price_origin)

    # Calcular conversion_rate inverso
    conversion_rate_inverse =
      Decimal.div(transaction.price_destination, transaction.price_origin)

    # Revertir balances
    new_balance_from = Decimal.add(account_from.balance, amount_reverted)
    new_balance_to = Decimal.sub(account_to.balance, transaction.amount_converted)

    account_from
    |> Account.changeset(%{balance: new_balance_from})
    |> Repo.update!()

    account_to
    |> Account.changeset(%{balance: new_balance_to})
    |> Repo.update!()

    # Crear transacción inversa con precios históricos originales
    %Transaction{}
    |> Transaction.changeset(%{
      type: "swap",
      amount: transaction.amount_converted,
      amount_converted: amount_reverted,
      account_from_id: account_to.id,
      account_to_id: account_from.id,
      currency_from_id: transaction.currency_to_id,
      currency_to_id: transaction.currency_from_id,
      # Usar precios históricos originales para reproducir exactamente
      price_origin: transaction.price_destination,
      price_destination: transaction.price_origin,
      conversion_rate: conversion_rate_inverse
    })
    |> Repo.insert!()
  end

  @doc """
  Obtiene una transacción por su ID.
  """
  def get_transaction(id) do
    Repo.get(Transaction, id)
    |> Repo.preload([:account_from, :account_to, :currency_from, :currency_to])
  end

  @doc """
  Lista todas las transacciones ordenadas por timestamp descendente.
  """
  def list_transactions do
    from(t in Transaction,
      order_by: [desc: t.timestamp, desc: t.id],
      preload: [:account_from, :account_to, :currency_from, :currency_to]
    )
    |> Repo.all()
  end

  @doc """
  Lista todas las transacciones de un usuario específico.
  """
  def list_user_transactions(user_id) do
    # Obtener IDs de todas las cuentas del usuario
    account_ids =
      from(a in Account,
        where: a.user_id == ^user_id,
        select: a.id
      )
      |> Repo.all()

    # Obtener transacciones donde el usuario participa
    from(t in Transaction,
      where:
        t.account_from_id in ^account_ids or t.account_to_id in ^account_ids,
      order_by: [desc: t.timestamp, desc: t.id],
      preload: [:account_from, :account_to, :currency_from, :currency_to]
    )
    |> Repo.all()
  end

  # Helper para asegurar que un valor es Decimal
  defp ensure_decimal(%Decimal{} = value), do: value
  defp ensure_decimal(value) when is_binary(value), do: Decimal.new(value)
  defp ensure_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp ensure_decimal(value) when is_float(value), do: Decimal.from_float(value)
end
