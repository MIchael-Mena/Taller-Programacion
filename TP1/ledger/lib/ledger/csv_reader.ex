defmodule Ledger.CSVReader do
  @moduledoc """
  Módulo para leer y parsear archivos CSV del sistema Ledger.
  """

  defmodule Transaccion do
    @moduledoc """
    Estructura que representa una transacción del sistema.
    """
    defstruct [
      :id_transaccion,
      :timestamp,
      :moneda_origen,
      :moneda_destino,
      :monto,
      :cuenta_origen,
      :cuenta_destino,
      :tipo
    ]
  end

  defmodule Moneda do
    @moduledoc """
    Estructura que representa una moneda del sistema.
    """
    defstruct [
      :nombre_moneda,
      :precio_usd
    ]
  end

  @doc """
  Lee el archivo de transacciones y devuelve una lista de structs Transaccion.
  En caso de error de formato, retorna {:error, nro_linea}.
  """
  def read_transacciones(archivo \\ "transacciones.csv") do
    case File.read(archivo) do
      {:ok, contenido} ->
        parse_transacciones_con_validacion(contenido)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lee el archivo de monedas y devuelve una lista de structs Moneda.
  En caso de error de formato, retorna {:error, nro_linea}.
  """
  def read_monedas(archivo \\ "monedas.csv") do
    case File.read(archivo) do
      {:ok, contenido} ->
        parse_monedas_con_validacion(contenido)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Valida que todas las transacciones usen monedas existentes.
  Retorna {:error, nro_linea} si encuentra una moneda inexistente.
  """
  def validate_transacciones_con_monedas(transacciones, monedas) do
    monedas_validas = MapSet.new(monedas, & &1.nombre_moneda)

    transacciones
    |> Enum.with_index(2)  # Empezar en línea 2 (después del header)
    |> Enum.find(fn {transaccion, _linea} ->
      (transaccion.moneda_origen && !MapSet.member?(monedas_validas, transaccion.moneda_origen)) ||
      (transaccion.moneda_destino && !MapSet.member?(monedas_validas, transaccion.moneda_destino))
    end)
    |> case do
      nil -> :ok
      {_transaccion, linea} -> {:error, linea}
    end
  end

  @doc """
  Lee y valida tanto transacciones como monedas, retornando error si hay inconsistencias.
  """
  def read_and_validate_all(archivo_transacciones \\ "transacciones.csv", archivo_monedas \\ "monedas.csv") do
    with {:ok, transacciones} <- read_transacciones(archivo_transacciones),
         {:ok, monedas} <- read_monedas(archivo_monedas),
         :ok <- validate_transacciones_con_monedas(transacciones, monedas) do
      {:ok, {transacciones, monedas}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calcula el balance de una cuenta específica basándose en todas las transacciones.
  Retorna un mapa con moneda => balance.

  NOTA IMPORTANTE: Los balances pueden ser negativos. Esto es comportamiento esperado
  cuando una cuenta realiza transacciones que exceden su saldo disponible o cuando
  se realizan swaps que dejan saldos negativos en la moneda origen.

  Ejemplos de balances negativos válidos:
  - Swap de ETH a BTC: La cuenta queda con ETH negativo y BTC positivo
  - Transferencia sin fondos suficientes: La cuenta queda con saldo negativo
  - Operaciones complejas de trading que involucran múltiples monedas
  """
  def calcular_balance(cuenta, archivo_transacciones \\ "transacciones.csv", archivo_monedas \\ "monedas.csv") do
    case read_and_validate_all(archivo_transacciones, archivo_monedas) do
      {:ok, {transacciones, _monedas}} ->
        balance = calcular_balance_cuenta(transacciones, cuenta)
        {:ok, balance}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Convierte balances a una moneda específica usando las tasas de cambio.
  """
  def convertir_balance_a_moneda(balance, moneda_destino, archivo_monedas \\ "monedas.csv") do
    case read_monedas(archivo_monedas) do
      {:ok, monedas} ->
        precio_destino = obtener_precio_moneda(monedas, moneda_destino)
        if precio_destino do
          balance_convertido = Enum.reduce(balance, 0.0, fn {moneda_origen, monto}, acc ->
            precio_origen = obtener_precio_moneda(monedas, moneda_origen)
            if precio_origen do
              # Convertir a USD y luego a moneda destino
              monto_usd = monto * precio_origen
              monto_destino = monto_usd / precio_destino
              acc + monto_destino
            else
              acc
            end
          end)
          {:ok, balance_convertido}
        else
          {:error, "Moneda destino no encontrada: #{moneda_destino}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_transacciones_con_validacion(contenido) do
    lineas = String.split(contenido, "\n", trim: true)

    case parse_transacciones_validando_lineas(lineas) do
      {:error, nro_linea} -> {:error, nro_linea}
      transacciones -> {:ok, transacciones}
    end
  end

  defp parse_transacciones_validando_lineas(lineas) do
    lineas
    |> Enum.drop(1)  # Saltar header
    |> Enum.with_index(2)  # Empezar numeración en línea 2
    |> Enum.reduce_while([], fn {linea, nro_linea}, acc ->
      case parse_transaccion_line_con_validacion(linea, nro_linea) do
        {:error, error_linea} -> {:halt, {:error, error_linea}}
        {:ok, nil} -> {:cont, acc}  # Línea vacía o inválida pero no crítica
        {:ok, transaccion} -> {:cont, [transaccion | acc]}
      end
    end)
    |> case do
      {:error, nro_linea} -> {:error, nro_linea}
      transacciones -> Enum.reverse(transacciones)
    end
  end

  defp parse_transaccion_line_con_validacion(line, nro_linea) do
    campos = String.split(line, ";")

    # Validar número de campos
    if length(campos) != 8 do
      {:error, nro_linea}
    else
      [id, timestamp, moneda_origen, moneda_destino, monto, cuenta_origen, cuenta_destino, tipo] = campos

      # Validar campos obligatorios y tipos
      with {:ok, id_int} <- validate_positive_integer(id, nro_linea),
           {:ok, timestamp_int} <- validate_positive_integer(timestamp, nro_linea),
           {:ok, monto_float} <- validate_positive_float(monto, nro_linea),
           {:ok, tipo_valido} <- validate_tipo_transaccion(tipo, nro_linea) do

        transaccion = %Transaccion{
          id_transaccion: id_int,
          timestamp: timestamp_int,
          moneda_origen: parse_string(moneda_origen),
          moneda_destino: parse_string(moneda_destino),
          monto: monto_float,
          cuenta_origen: parse_string(cuenta_origen),
          cuenta_destino: parse_string(cuenta_destino),
          tipo: tipo_valido
        }

        # Validar lógica de negocio según tipo de transacción
        case validate_transaccion_logica(transaccion, nro_linea) do
          :ok -> {:ok, transaccion}
          {:error, _} -> {:error, nro_linea}
        end
      else
        {:error, _} -> {:error, nro_linea}
      end
    end
  end

  defp parse_monedas_con_validacion(contenido) do
    lineas = String.split(contenido, "\n", trim: true)

    case parse_monedas_validando_lineas(lineas) do
      {:error, nro_linea} -> {:error, nro_linea}
      monedas -> {:ok, monedas}
    end
  end

  defp parse_monedas_validando_lineas(lineas) do
    lineas
    |> Enum.drop(1)  # Saltar header
    |> Enum.with_index(2)  # Empezar numeración en línea 2
    |> Enum.reduce_while([], fn {linea, nro_linea}, acc ->
      case parse_moneda_line_con_validacion(linea, nro_linea) do
        {:error, error_linea} -> {:halt, {:error, error_linea}}
        {:ok, nil} -> {:cont, acc}  # Línea vacía
        {:ok, moneda} -> {:cont, [moneda | acc]}
      end
    end)
    |> case do
      {:error, nro_linea} -> {:error, nro_linea}
      monedas -> Enum.reverse(monedas)
    end
  end

  defp parse_moneda_line_con_validacion(line, nro_linea) do
    campos = String.split(line, ";")

    if length(campos) != 2 do
      {:error, nro_linea}
    else
      [nombre_moneda, precio_usd] = campos

      # Validar que nombre no esté vacío y precio sea positivo
      with {:ok, nombre_valido} <- validate_non_empty_string(nombre_moneda, nro_linea),
           {:ok, precio_valido} <- validate_positive_float(precio_usd, nro_linea) do

        moneda = %Moneda{
          nombre_moneda: nombre_valido,
          precio_usd: precio_valido
        }

        {:ok, moneda}
      else
        {:error, _} -> {:error, nro_linea}
      end
    end
  end

  # Funciones auxiliares de validación
  defp validate_positive_integer(str, nro_linea) do
    case Integer.parse(str) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, nro_linea}
    end
  end

  defp validate_positive_float(str, nro_linea) do
    case Float.parse(str) do
      {float, ""} when float > 0 -> {:ok, float}
      _ ->
        # Intentar como entero también
        case Integer.parse(str) do
          {int, ""} when int > 0 -> {:ok, int * 1.0}
          _ -> {:error, nro_linea}
        end
    end
  end

  defp validate_non_empty_string("", nro_linea), do: {:error, nro_linea}
  defp validate_non_empty_string(str, _nro_linea), do: {:ok, str}

  defp validate_tipo_transaccion(tipo, nro_linea) do
    if tipo in ["transferencia", "swap", "alta_cuenta"] do
      {:ok, tipo}
    else
      {:error, nro_linea}
    end
  end

  defp validate_transaccion_logica(transaccion, nro_linea) do
    case transaccion.tipo do
      "transferencia" ->
        # Debe tener cuenta origen y destino
        if transaccion.cuenta_origen && transaccion.cuenta_destino do
          :ok
        else
          {:error, nro_linea}
        end

      "alta_cuenta" ->
        # Debe tener cuenta origen, no debe tener cuenta destino
        if transaccion.cuenta_origen && !transaccion.cuenta_destino do
          :ok
        else
          {:error, nro_linea}
        end

      "swap" ->
        # Debe tener cuenta origen, monedas origen y destino diferentes
        if transaccion.cuenta_origen && transaccion.moneda_origen && transaccion.moneda_destino &&
           transaccion.moneda_origen != transaccion.moneda_destino do
          :ok
        else
          {:error, nro_linea}
        end

      _ ->
        {:error, nro_linea}
    end
  end

  # Funciones auxiliares para cálculo de balances

  defp calcular_balance_cuenta(transacciones, cuenta) do
    transacciones
    |> Enum.filter(&transaccion_afecta_cuenta?(&1, cuenta))
    |> Enum.reduce(%{}, fn transaccion, balance ->
        actualizar_balance_con_transaccion(transaccion, balance, cuenta)
    end)
  end

  defp transaccion_afecta_cuenta?(transaccion, cuenta) do
    transaccion.cuenta_origen == cuenta || transaccion.cuenta_destino == cuenta
  end

  defp actualizar_balance_con_transaccion(transaccion, balance, cuenta) do
    case transaccion.tipo do
      "transferencia" ->
        actualizar_balance_transferencia(transaccion, balance, cuenta)

      "swap" ->
        actualizar_balance_swap(transaccion, balance, cuenta)

      "alta_cuenta" ->
        actualizar_balance_alta_cuenta(transaccion, balance, cuenta)

      _ ->
        balance
    end
  end

  defp actualizar_balance_transferencia(transaccion, balance, cuenta) do
    cond do
      transaccion.cuenta_origen == cuenta ->
        # Esta cuenta está enviando dinero (débito)
        debitar_cuenta(balance, transaccion.moneda_origen, transaccion.monto)

      transaccion.cuenta_destino == cuenta ->
        # Esta cuenta está recibiendo dinero (crédito)
        acreditar_cuenta(balance, transaccion.moneda_destino, transaccion.monto)

      true ->
        balance
    end
  end

  defp actualizar_balance_swap(transaccion, balance, cuenta) do
    if transaccion.cuenta_origen == cuenta do
      # En un swap, la cuenta pierde moneda_origen y gana moneda_destino
      balance
      |> debitar_cuenta(transaccion.moneda_origen, transaccion.monto)
      |> acreditar_cuenta(transaccion.moneda_destino, transaccion.monto)
    else
      balance
    end
  end

  defp actualizar_balance_alta_cuenta(transaccion, balance, cuenta) do
    if transaccion.cuenta_origen == cuenta do
      # Alta cuenta crea la cuenta con el monto inicial
      acreditar_cuenta(balance, transaccion.moneda_origen, transaccion.monto)
    else
      balance
    end
  end

  defp debitar_cuenta(balance, moneda, monto) do
    # NOTA: Esta función puede generar balances negativos, lo cual es comportamiento esperado
    # en un sistema contable que registra todas las transacciones sin validar fondos
    Map.update(balance, moneda, -monto, fn saldo_actual -> saldo_actual - monto end)
  end

  defp acreditar_cuenta(balance, moneda, monto) do
    Map.update(balance, moneda, monto, fn saldo_actual -> saldo_actual + monto end)
  end

  defp obtener_precio_moneda(monedas, nombre_moneda) do
    moneda = Enum.find(monedas, fn m -> m.nombre_moneda == nombre_moneda end)
    if moneda, do: moneda.precio_usd, else: nil
  end

  defp parse_string(""), do: nil
  defp parse_string(str), do: str
end
