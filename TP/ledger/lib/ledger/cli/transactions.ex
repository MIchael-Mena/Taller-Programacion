defmodule Ledger.CLI.Transactions do
  @moduledoc """
  Comandos CLI para gestión de transacciones.

  Maneja los comandos:
  - alta_cuenta: Crear cuenta con balance inicial
  - realizar_transferencia: Transferir entre usuarios
  - realizar_swap: Convertir entre monedas
  - deshacer_transaccion: Deshacer última transacción
  - ver_transaccion: Ver detalles de transacción
  """

  alias Ledger.Transactions
  alias Ledger.Repo

  @doc """
  Crea una cuenta para un usuario con un balance inicial.

  ## Ejemplo
      ./ledger alta_cuenta -u=1 -m=2 -a=1000.50
  """
  def alta_cuenta(args) do
    with {:ok, user_id_str} <- get_arg(args, ["-u"], "usuario"),
         {:ok, user_id} <- parse_integer(user_id_str, "usuario"),
         {:ok, currency_id_str} <- get_arg(args, ["-m"], "moneda"),
         {:ok, currency_id} <- parse_integer(currency_id_str, "moneda"),
         {:ok, amount_str} <- get_arg(args, ["-a"], "monto"),
         {:ok, amount} <- parse_decimal(amount_str, "monto") do
      case Transactions.alta_cuenta(user_id, currency_id, amount) do
        {:ok, transaction} ->
          IO.puts("✅ Cuenta creada exitosamente")
          IO.puts("ID Transacción: #{transaction.id}")
          IO.puts("Usuario ID: #{user_id}")
          IO.puts("Moneda ID: #{currency_id}")
          IO.puts("Balance inicial: #{amount}")
          IO.puts("Timestamp: #{transaction.timestamp}")

        {:error, reason} ->
          IO.puts("{:error, alta_cuenta: \"#{reason}\"}")
      end
    else
      {:error, reason} -> IO.puts("{:error, alta_cuenta: \"#{reason}\"}")
    end
  end

  @doc """
  Realiza una transferencia entre dos usuarios en la misma moneda.

  ## Ejemplo
      ./ledger realizar_transferencia -o=1 -d=2 -m=3 -a=500.75
  """
  def realizar_transferencia(args) do
    with {:ok, user_from_id_str} <- get_arg(args, ["-o"], "usuario origen"),
         {:ok, user_from_id} <- parse_integer(user_from_id_str, "usuario origen"),
         {:ok, user_to_id_str} <- get_arg(args, ["-d"], "usuario destino"),
         {:ok, user_to_id} <- parse_integer(user_to_id_str, "usuario destino"),
         {:ok, currency_id_str} <- get_arg(args, ["-m"], "moneda"),
         {:ok, currency_id} <- parse_integer(currency_id_str, "moneda"),
         {:ok, amount_str} <- get_arg(args, ["-a"], "monto"),
         {:ok, amount} <- parse_decimal(amount_str, "monto") do
      case Transactions.realizar_transferencia(user_from_id, user_to_id, currency_id, amount) do
        {:ok, transaction} ->
          IO.puts("✅ Transferencia realizada exitosamente")
          IO.puts("ID Transacción: #{transaction.id}")
          IO.puts("De usuario: #{user_from_id}")
          IO.puts("A usuario: #{user_to_id}")
          IO.puts("Moneda ID: #{currency_id}")
          IO.puts("Monto: #{amount}")
          IO.puts("Timestamp: #{transaction.timestamp}")

        {:error, reason} ->
          IO.puts("{:error, realizar_transferencia: \"#{reason}\"}")
      end
    else
      {:error, reason} -> IO.puts("{:error, realizar_transferencia: \"#{reason}\"}")
    end
  end

  @doc """
  Realiza un swap entre dos monedas del mismo usuario.

  ## Ejemplo
      ./ledger realizar_swap -u=1 -mo=2 -md=3 -a=1.5
  """
  def realizar_swap(args) do
    with {:ok, user_id_str} <- get_arg(args, ["-u"], "usuario"),
         {:ok, user_id} <- parse_integer(user_id_str, "usuario"),
         {:ok, currency_from_id_str} <- get_arg(args, ["-mo"], "moneda origen"),
         {:ok, currency_from_id} <- parse_integer(currency_from_id_str, "moneda origen"),
         {:ok, currency_to_id_str} <- get_arg(args, ["-md"], "moneda destino"),
         {:ok, currency_to_id} <- parse_integer(currency_to_id_str, "moneda destino"),
         {:ok, amount_str} <- get_arg(args, ["-a"], "monto"),
         {:ok, amount} <- parse_decimal(amount_str, "monto") do
      case Transactions.realizar_swap(user_id, currency_from_id, currency_to_id, amount) do
        {:ok, transaction} ->
          IO.puts("✅ Swap realizado exitosamente")
          IO.puts("ID Transacción: #{transaction.id}")
          IO.puts("Usuario ID: #{user_id}")
          IO.puts("De moneda: #{currency_from_id}")
          IO.puts("A moneda: #{currency_to_id}")
          IO.puts("Monto origen: #{amount}")
          IO.puts("Monto convertido: #{transaction.amount_converted}")
          IO.puts("Precio origen (USD): $#{transaction.price_origin}")
          IO.puts("Precio destino (USD): $#{transaction.price_destination}")
          IO.puts("Ratio conversión: #{transaction.conversion_rate}")
          IO.puts("Timestamp: #{transaction.timestamp}")

        {:error, reason} ->
          IO.puts("{:error, realizar_swap: \"#{reason}\"}")
      end
    else
      {:error, reason} -> IO.puts("{:error, realizar_swap: \"#{reason}\"}")
    end
  end

  @doc """
  Deshace una transacción si es la última de los usuarios involucrados.

  ## Ejemplo
      ./ledger deshacer_transaccion -id=5
  """
  def deshacer_transaccion(args) do
    with {:ok, transaction_id_str} <- get_arg(args, ["-id"], "transacción"),
         {:ok, transaction_id} <- parse_integer(transaction_id_str, "transacción") do
      case Transactions.deshacer_transaccion(transaction_id) do
        {:ok, reverse_transaction} ->
          IO.puts("✅ Transacción deshecha exitosamente")
          IO.puts("ID Transacción original: #{transaction_id}")
          IO.puts("ID Transacción inversa: #{reverse_transaction.id}")
          IO.puts("Tipo: #{reverse_transaction.type}")
          IO.puts("Timestamp: #{reverse_transaction.timestamp}")

        {:error, reason} ->
          IO.puts("{:error, deshacer_transaccion: \"#{reason}\"}")
      end
    else
      {:error, reason} -> IO.puts("{:error, deshacer_transaccion: \"#{reason}\"}")
    end
  end

  @doc """
  Muestra los detalles de una transacción.

  ## Ejemplo
      ./ledger ver_transaccion -id=5
  """
  def ver_transaccion(args) do
    with {:ok, transaction_id_str} <- get_arg(args, ["-id"], "transacción"),
         {:ok, transaction_id} <- parse_integer(transaction_id_str, "transacción") do
      case Transactions.get_transaction(transaction_id) do
        nil ->
          IO.puts("{:error, ver_transaccion: \"La transacción no existe\"}")

        transaction ->
          IO.puts("=" <> String.duplicate("=", 60))
          IO.puts("TRANSACCIÓN ##{transaction.id}")
          IO.puts("=" <> String.duplicate("=", 60))
          IO.puts("")
          IO.puts("Tipo: #{transaction.type}")
          IO.puts("Timestamp: #{transaction.timestamp}")
          IO.puts("Monto: #{transaction.amount}")

          if transaction.amount_converted do
            IO.puts("Monto convertido: #{transaction.amount_converted}")
          end

          IO.puts("")
          IO.puts("--- Cuentas ---")

          if transaction.account_from do
            account_from = Repo.preload(transaction.account_from, [:user, :currency])

            IO.puts(
              "Origen: Usuario '#{account_from.user.username}' (ID: #{account_from.user_id}) - #{account_from.currency.name}"
            )
          else
            IO.puts("Origen: N/A (alta de cuenta)")
          end

          account_to = Repo.preload(transaction.account_to, [:user, :currency])

          IO.puts(
            "Destino: Usuario '#{account_to.user.username}' (ID: #{account_to.user_id}) - #{account_to.currency.name}"
          )

          IO.puts("")

          if transaction.type == "swap" do
            IO.puts("--- Detalles del Swap ---")
            currency_from = transaction.currency_from
            currency_to = transaction.currency_to

            IO.puts("De: #{currency_from.name} ($#{currency_from.price_usd} USD)")
            IO.puts("A: #{currency_to.name} ($#{currency_to.price_usd} USD)")
            IO.puts("")
            IO.puts("--- Precios Históricos (al momento de la transacción) ---")
            IO.puts("Precio origen: $#{transaction.price_origin} USD")
            IO.puts("Precio destino: $#{transaction.price_destination} USD")
            IO.puts("Ratio conversión: #{transaction.conversion_rate}")
          end

          if transaction.type == "transferencia" do
            IO.puts("--- Detalles de Transferencia ---")
            currency = transaction.currency_from || transaction.currency_to
            IO.puts("Moneda: #{currency.name} ($#{currency.price_usd} USD)")
            IO.puts("Precio histórico: $#{transaction.price_origin} USD")
          end

          IO.puts("")
          IO.puts("Creado: #{transaction.inserted_at}")
          IO.puts("=" <> String.duplicate("=", 60))
      end
    else
      {:error, reason} -> IO.puts("{:error, ver_transaccion: \"#{reason}\"}")
    end
  end

  # Helpers privados

  defp get_arg(args, flags, field_name) when is_list(flags) do
    # Buscar el argumento con alguno de los flags
    result =
      Enum.find_value(flags, fn flag ->
        Enum.find_value(args, fn arg ->
          case arg do
            ^flag <> "=" <> value -> value
            _ -> nil
          end
        end)
      end)

    case result do
      nil -> {:error, "El campo #{field_name} es obligatorio"}
      value -> {:ok, value}
    end
  end

  defp parse_integer(value, field_name) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "El #{field_name} debe ser un número entero válido"}
    end
  end

  defp parse_decimal(value, field_name) do
    try do
      decimal = Decimal.new(value)
      {:ok, decimal}
    rescue
      _ -> {:error, "El #{field_name} debe ser un número válido"}
    end
  end
end
