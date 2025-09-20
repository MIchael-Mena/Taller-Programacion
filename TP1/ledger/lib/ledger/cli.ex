defmodule Ledger.CLI do
  @moduledoc """
  Módulo de línea de comandos para el sistema Ledger.

  Este módulo pr    if opts[:c1] do
      cuenta = opts[:c1]orciona la interfaz de línea de comandos para interactuar
  con el sistema de libros contables (ledger).
  """

  def main(args \\ []) do
    args
    |> preprocess_single_dash_flags()
    |> parse_args()
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
        "-o=" <> value -> "--o=" <> value
        other -> other
      end
    end)
  end

  defp parse_args(args) do
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
          o: :string
        ],
        aliases: [
          h: :help,
          v: :version
        ],
        allow_nonexistent_atoms: false
      )

    {opts, commands}
  end

  defp process_command({opts, commands}) do
    cond do
      opts[:help] -> show_help()
      opts[:version] -> show_version()
      commands == [] -> show_welcome()
      true -> execute_commands(commands, opts)
    end
  end

  defp show_welcome do
    IO.puts("¡Bienvenido al sistema Ledger!")
    IO.puts("Usa --help para ver las opciones disponibles.")
  end

  defp execute_commands(commands, opts) do
    case commands do
      ["transacciones" | _] ->
        handle_transacciones(opts)
      ["balance" | _] ->
        handle_balance(opts)
      _ ->
        IO.puts("Comando no reconocido: #{Enum.join(commands, " ")}")
        IO.puts("Comandos disponibles: transacciones, balance")
        IO.puts("Usa --help para más información")
    end
  end

  defp handle_transacciones(opts) do
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

  defp handle_balance(opts) do
    if opts[:c1] do
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
    else
      IO.puts("Error: El flag -c1 es obligatorio para el comando balance")
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

      case opts[:o] do
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

    Subcomandos:
      transacciones  Listar transacciones filtradas
      balance        Mostrar balance de una cuenta

    Opciones globales:
      -h         Muestra esta ayuda
      -v         Muestra la versión

    Opciones para subcomandos:
      -c1=CUENTA     Especifica la cuenta origen (obligatorio para balance)
      -c2=CUENTA     Especifica la cuenta destino
      -t=ARCHIVO     Archivo de transacciones (default: transacciones.csv)
      -m=MONEDA      Moneda para cálculo de balances o conversión
      -o=ARCHIVO     Archivo de salida (default: terminal)

    Ejemplos:
      ledger transacciones
        Lista todas las transacciones

      ledger transacciones -c1=userA -o=result.csv
        Lista transacciones de userA y las guarda en result.csv

      ledger balance -c1=userA
        Muestra el balance de userA en todas las monedas

      ledger balance -c1=userA -m=BTC
        Muestra el balance de userA convertido a BTC
    """)
  end

  defp show_version do
    IO.puts("Ledger versión 1.0.0")
  end
end
