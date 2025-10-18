defmodule Ledger.CLI do
  @moduledoc """
  Módulo de línea de comandos para el sistema Ledger.

  Este módulo pr    if opts[:c1] do
      cuenta = opts[:c1]orciona la interfaz de línea de comandos para interactuar
  con el sistema de libros contables (ledger).
  """

  def main(args \\ []) do
    # Guardar args originales antes de preprocesar
    original_args = args

    args
    |> preprocess_single_dash_flags()
    |> parse_args(original_args)
    |> process_command()
  end

  # Convertir single-dash multi-char flags a double-dash para evitar warnings
  defp preprocess_single_dash_flags(args) do
    Enum.map(args, fn arg ->
      case arg do
        "-c1=" <> value -> "--c1=" <> value
        "-c2=" <> value -> "--c2=" <> value
        "-t=" <> value -> "--t=" <> value
        "-m=" <> value -> "--m=" <> value
        "-out=" <> value -> "--out=" <> value
        other -> other
      end
    end)
  end

  defp parse_args(args, original_args) do
    {opts, commands, _} =
      args
      |> OptionParser.parse(
        switches: [
          help: :boolean,
          version: :boolean,
          c1: :string,
          c2: :string,
          t: :string,
          m: :string,
          out: :string
        ],
        aliases: [
          h: :help,
          v: :version
        ],
        allow_nonexistent_atoms: false
      )

    {opts, commands, original_args}
  end

  defp process_command({opts, commands, original_args}) do
    cond do
      opts[:help] -> show_help()
      opts[:version] -> show_version()
      commands == [] -> show_welcome()
      true -> execute_commands(commands, opts, original_args)
    end
  end

  defp show_welcome do
    IO.puts("¡Bienvenido al sistema Ledger!")
    IO.puts("Usa --help para ver las opciones disponibles.")
  end

  defp execute_commands(commands, opts, original_args) do
    case commands do
      ["transacciones" | _] ->
        handle_transacciones(opts)
      ["balance" | _] ->
        handle_balance(opts)
      ["crear_usuario" | _] ->
        # Extraer argumentos después del comando
        args_after_command = Enum.drop_while(original_args, &(&1 != "crear_usuario")) |> tl()
        Ledger.CLI.Users.crear_usuario(args_after_command)
      ["editar_usuario" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "editar_usuario")) |> tl()
        Ledger.CLI.Users.editar_usuario(args_after_command)
      ["borrar_usuario" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "borrar_usuario")) |> tl()
        Ledger.CLI.Users.borrar_usuario(args_after_command)
      ["ver_usuario" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "ver_usuario")) |> tl()
        Ledger.CLI.Users.ver_usuario(args_after_command)
      ["crear_moneda" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "crear_moneda")) |> tl()
        Ledger.CLI.Currencies.crear_moneda(args_after_command)
      ["editar_moneda" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "editar_moneda")) |> tl()
        Ledger.CLI.Currencies.editar_moneda(args_after_command)
      ["borrar_moneda" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "borrar_moneda")) |> tl()
        Ledger.CLI.Currencies.borrar_moneda(args_after_command)
      ["ver_moneda" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "ver_moneda")) |> tl()
        Ledger.CLI.Currencies.ver_moneda(args_after_command)
      ["alta_cuenta" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "alta_cuenta")) |> tl()
        Ledger.CLI.Transactions.alta_cuenta(args_after_command)
      ["realizar_transferencia" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "realizar_transferencia")) |> tl()
        Ledger.CLI.Transactions.realizar_transferencia(args_after_command)
      ["realizar_swap" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "realizar_swap")) |> tl()
        Ledger.CLI.Transactions.realizar_swap(args_after_command)
      ["deshacer_transaccion" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "deshacer_transaccion")) |> tl()
        Ledger.CLI.Transactions.deshacer_transaccion(args_after_command)
      ["ver_transaccion" | _] ->
        args_after_command = Enum.drop_while(original_args, &(&1 != "ver_transaccion")) |> tl()
        Ledger.CLI.Transactions.ver_transaccion(args_after_command)
      _ ->
        IO.puts("Comando no reconocido: #{Enum.join(commands, " ")}")
        IO.puts("Comandos disponibles: transacciones, balance, crear_usuario, editar_usuario, borrar_usuario, ver_usuario, crear_moneda, editar_moneda, borrar_moneda, ver_moneda, alta_cuenta, realizar_transferencia, realizar_swap, deshacer_transaccion, ver_transaccion")
        IO.puts("Usa --help para más información")
    end
  end

  defp handle_transacciones(opts) do
    # Detectar si debemos usar BD o CSV
    if database_available?() and is_nil(opts[:t]) do
      handle_transacciones_db(opts)
    else
      handle_transacciones_csv(opts)
    end
  end

  defp handle_transacciones_csv(opts) do
    # Archivo de transacciones (default: transacciones.csv)
    archivo_transacciones = opts[:t] || "transacciones.csv"
    # Archivo de monedas (extensión: permite -m para especificar archivo alternativo en tests)
    archivo_monedas = opts[:m] || "monedas.csv"

    # Leer y validar transacciones y monedas
    case Ledger.CSVReader.read_and_validate_all(archivo_transacciones, archivo_monedas) do
      {:ok, {transacciones, _monedas}} ->
        transacciones_filtradas = filter_transacciones(transacciones, opts)
        output_transacciones(transacciones_filtradas, opts)

      {:error, nro_linea} when is_integer(nro_linea) ->
        IO.puts("{:error, #{nro_linea}}")

      {:error, reason} ->
        IO.puts("Error al leer #{archivo_transacciones}: #{reason}")
    end
  end

  defp handle_transacciones_db(opts) do
    # Obtener transacciones de la base de datos
    transactions = Ledger.Transactions.list_transactions()

    # Filtrar por username si se especificó -c1 o -c2
    transactions_filtradas =
      transactions
      |> Enum.filter(fn t ->
        match_c1 = if opts[:c1], do: matches_user?(t, opts[:c1], :from), else: true
        match_c2 = if opts[:c2], do: matches_user?(t, opts[:c2], :to), else: true
        match_c1 and match_c2
      end)

    # Convertir a formato similar al CSV para reutilizar output
    transacciones_formateadas = Enum.map(transactions_filtradas, &format_transaction_from_db/1)
    output_transacciones(transacciones_formateadas, opts)
  end

  defp handle_balance(opts) do
    if opts[:c1] do
      # Detectar si debemos usar BD o CSV
      if database_available?() and is_nil(opts[:t]) do
        handle_balance_db(opts)
      else
        handle_balance_csv(opts)
      end
    else
      IO.puts("Error: El flag -c1 es obligatorio para el comando balance")
    end
  end

  defp handle_balance_csv(opts) do
    cuenta = opts[:c1]
    archivo_transacciones = opts[:t] || "transacciones.csv"
    archivo_monedas = "monedas.csv"  # Siempre usar archivo por defecto para monedas
    moneda_conversion = opts[:m]  # Esta es la moneda destino para conversión

    case Ledger.CSVReader.calcular_balance(cuenta, archivo_transacciones, archivo_monedas) do
      {:ok, balance} ->
        if moneda_conversion do
          # Convertir todo el balance a la moneda especificada
          case Ledger.CSVReader.convertir_balance_a_moneda(balance, moneda_conversion, archivo_monedas) do
            {:ok, balance_convertido} ->
              IO.puts("#{moneda_conversion}=#{:erlang.float_to_binary(balance_convertido, [{:decimals, 6}])}")

            {:error, reason} ->
              IO.puts("Error al convertir balance: #{reason}")
          end
        else
          # Mostrar balance en todas las monedas
          output_balance(balance)
        end

      {:error, nro_linea} when is_integer(nro_linea) ->
        IO.puts("{:error, #{nro_linea}}")

      {:error, reason} ->
        IO.puts("Error al calcular balance: #{reason}")
    end
  end

  defp filter_transacciones(transacciones, opts) do
    transacciones
    |> maybe_filter_c1(opts[:c1])
    |> maybe_filter_c2(opts[:c2])
  end

  defp maybe_filter_c1(transacciones, nil), do: transacciones
  defp maybe_filter_c1(transacciones, cuenta_origen) do
    Enum.filter(transacciones, fn t -> t.cuenta_origen == cuenta_origen end)
  end

  defp maybe_filter_c2(transacciones, nil), do: transacciones
  defp maybe_filter_c2(transacciones, cuenta_destino) do
    Enum.filter(transacciones, fn t -> t.cuenta_destino == cuenta_destino end)
  end

  defp output_transacciones(transacciones, opts) do
    if Enum.empty?(transacciones) do
      IO.puts("No se encontraron transacciones que coincidan con los filtros.")
    else
      output = format_transacciones(transacciones)

      case opts[:out] do
        nil ->
          IO.puts(output)

        archivo_output ->
          case File.write(archivo_output, output) do
            :ok ->
              IO.puts("Transacciones guardadas en #{archivo_output}")

            {:error, reason} ->
              IO.puts("Error al escribir en #{archivo_output}: #{reason}")
          end
      end
    end
  end

  defp format_transacciones(transacciones) do
    rows = Enum.map(transacciones, fn t ->
      moneda_destino = if t.moneda_destino, do: t.moneda_destino, else: ""
      cuenta_destino = if t.cuenta_destino, do: t.cuenta_destino, else: ""

      "#{t.id_transaccion};#{t.timestamp};#{t.moneda_origen};#{moneda_destino};#{t.monto};#{t.cuenta_origen};#{cuenta_destino};#{t.tipo}"
    end)

    rows |> Enum.join("\n")
  end

  defp output_balance(balance) do
    # Formatear balance según requerimiento: MONEDA=BALANCE(6 decimales siempre)
    balance
    |> Enum.sort_by(fn {moneda, _} -> moneda end)  # Ordenar por moneda para salida consistente
    |> Enum.each(fn {moneda, monto} ->
      monto_formateado = :erlang.float_to_binary(monto, [{:decimals, 6}])
      IO.puts("#{moneda}=#{monto_formateado}")
    end)
  end

  defp show_help do
    IO.puts("""
    Ledger - Sistema de libros contables

    Uso: ledger <subcomando> [opciones]

    Subcomandos (TP1):
      transacciones  Listar transacciones filtradas
      balance        Mostrar balance de una cuenta

    Subcomandos (TP2 - Usuarios):
      crear_usuario -n=<nombre-de-usuario> -b=<fecha-nacimiento>
      editar_usuario -id=<id-usuario> -n=<nuevo-nombre-de-usuario>
      borrar_usuario -id=<id-usuario>
      ver_usuario -id=<id-usuario>

    Subcomandos (TP2 - Monedas):
      crear_moneda -n=<nombre-de-moneda> -p=<precio-respecto-dolar>
      editar_moneda -id=<id-moneda> -p=<nuevo-precio-respecto-dolar>
      borrar_moneda -id=<id-moneda>
      ver_moneda -id=<id-moneda>

    Subcomandos (TP2 - Transacciones):
      alta_cuenta -u=<id-usuario> -m=<id-moneda> -a=<monto>
      realizar_transferencia -o=<id-usuario-origen> -d=<id-usuario-destino> -m=<id-moneda> -a=<monto>
      realizar_swap -u=<id-usuario> -mo=<id-moneda-origen> -md=<id-moneda-destino> -a=<monto>
      deshacer_transaccion -id=<id-transaccion>
      ver_transaccion -id=<id-transaccion>

    Opciones globales:
      -h         Muestra esta ayuda
      -v         Muestra la versión

    Opciones para subcomandos TP1:
      -c1=CUENTA     Especifica la cuenta origen (obligatorio para balance)
      -c2=CUENTA     Especifica la cuenta destino
      -t=ARCHIVO     Archivo de transacciones (default: transacciones.csv)
      -m=MONEDA      Moneda para cálculo de balances o conversión
      -out=ARCHIVO   Archivo de salida (default: terminal)

    Ejemplos TP1:
      ledger transacciones
        Lista todas las transacciones

      ledger transacciones -c1=userA -out=result.csv
        Lista transacciones de userA y las guarda en result.csv

      ledger balance -c1=userA
        Muestra el balance de userA en todas las monedas

      ledger balance -c1=userA -m=BTC
        Muestra el balance de userA convertido a BTC

    Ejemplos TP2 (Usuarios):
      ledger crear_usuario -n=juan_perez -b=1990-05-15
        Crea un usuario con nombre juan_perez

      ledger editar_usuario -id=1 -n=nuevo_nombre
        Cambia el nombre del usuario con ID 1

      ledger ver_usuario -id=1
        Muestra la información del usuario con ID 1

      ledger borrar_usuario -id=1
        Elimina el usuario con ID 1 (si no tiene transacciones)

    Ejemplos TP2 (Monedas):
      ledger crear_moneda -n=BTC -p=55000.0
        Crea una moneda BTC con precio de $55000

      ledger editar_moneda -id=1 -p=56000.0
        Actualiza el precio de la moneda con ID 1

      ledger ver_moneda -id=1
        Muestra la información de la moneda con ID 1

      ledger borrar_moneda -id=1
        Elimina la moneda con ID 1 (si no tiene transacciones)

    Ejemplos TP2 (Transacciones):
      ledger alta_cuenta -u=1 -m=2 -a=1000.50
        Crea una cuenta para el usuario 1 en la moneda 2 con balance inicial de 1000.50

      ledger realizar_transferencia -o=1 -d=2 -m=3 -a=500.75
        Transfiere 500.75 de la moneda 3 del usuario 1 al usuario 2

      ledger realizar_swap -u=1 -mo=2 -md=3 -a=1.5
        Convierte 1.5 unidades de la moneda 2 a la moneda 3 para el usuario 1

      ledger deshacer_transaccion -id=5
        Deshace la transacción con ID 5 (si es la última de los usuarios involucrados)

      ledger ver_transaccion -id=5
        Muestra los detalles completos de la transacción con ID 5
    """)
  end

  defp show_version do
    IO.puts("Ledger versión 1.0.0")
  end

  # ============================================================================
  # Funciones helper para integración TP1 + TP2
  # ============================================================================

  # Detecta si la base de datos está disponible y configurada
  defp database_available?() do
    try do
      Ledger.Repo.__adapter__()
      true
    rescue
      _ -> false
    end
  end

  # Formatea una transacción de BD al formato del CSV para reutilizar output
  defp format_transaction_from_db(transaction) do
    transaction = Ledger.Repo.preload(transaction, [:account_from, :account_to, :currency_from, :currency_to])

    cuenta_origen = if transaction.account_from do
      account = Ledger.Repo.preload(transaction.account_from, :user)
      account.user.username
    else
      ""
    end

    account_to = Ledger.Repo.preload(transaction.account_to, :user)

    %{
      id_transaccion: transaction.id,
      timestamp: DateTime.to_unix(transaction.timestamp),
      moneda_origen: if(transaction.currency_from, do: transaction.currency_from.name, else: ""),
      moneda_destino: transaction.currency_to.name,
      monto: Decimal.to_float(transaction.amount),
      cuenta_origen: cuenta_origen,
      cuenta_destino: account_to.user.username,
      tipo: transaction.type
    }
  end

  # Verifica si una transacción matchea con un username
  defp matches_user?(transaction, username, direction) do
    transaction = Ledger.Repo.preload(transaction, [:account_from, :account_to])

    case direction do
      :from ->
        if transaction.account_from do
          account = Ledger.Repo.preload(transaction.account_from, :user)
          account.user.username == username
        else
          false
        end

      :to ->
        account = Ledger.Repo.preload(transaction.account_to, :user)
        account.user.username == username
    end
  end

  # Maneja el balance desde la base de datos
  defp handle_balance_db(opts) do
    username = opts[:c1]
    moneda_conversion = opts[:m]

    # Buscar usuario por username
    case Ledger.Accounts.get_user_by_username(username) do
      nil ->
        IO.puts("{:error, balance: \"Usuario '#{username}' no encontrado\"}")

      user ->
        # Obtener todas las cuentas del usuario
        accounts = Ledger.Banking.list_user_accounts(user.id)
        accounts = Enum.map(accounts, &Ledger.Repo.preload(&1, :currency))

        if moneda_conversion do
          # Convertir todo a una moneda específica
          case convert_balance_to_currency_db(accounts, moneda_conversion) do
            {:ok, balance_total} ->
              IO.puts("#{moneda_conversion}=#{format_balance(balance_total)}")

            {:error, reason} ->
              IO.puts("{:error, balance: \"#{reason}\"}")
          end
        else
          # Mostrar balance en cada moneda
          Enum.each(accounts, fn account ->
            IO.puts("#{account.currency.name}=#{format_balance(Decimal.to_float(account.balance))}")
          end)
        end
    end
  end

  # Convierte todos los balances a una moneda específica
  defp convert_balance_to_currency_db(accounts, target_currency_name) do
    case Ledger.Currencies.get_currency_by_name(target_currency_name) do
      nil ->
        {:error, "Moneda '#{target_currency_name}' no encontrada"}

      target_currency ->
        if target_currency.price_usd == 0 do
          {:error, "No se puede convertir a una moneda con precio $0"}
        else
          total =
            accounts
            |> Enum.map(fn account ->
              balance = Decimal.to_float(account.balance)
              price_origin = account.currency.price_usd
              # Convertir a USD y luego a moneda destino
              (balance * price_origin) / target_currency.price_usd
            end)
            |> Enum.sum()

          {:ok, total}
        end
    end
  end

  # Formatea un balance con 6 decimales
  defp format_balance(balance) when is_float(balance) do
    :erlang.float_to_binary(balance, [{:decimals, 6}])
  end

  defp format_balance(balance) when is_integer(balance) do
    :erlang.float_to_binary(balance / 1, [{:decimals, 6}])
  end
end
