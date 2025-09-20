defmodule Ledger.CSVReaderTest do
  use ExUnit.Case
  alias Ledger.CSVReader

  @fixtures_path Path.expand("test/fixtures", __DIR__ |> Path.dirname() |> Path.dirname())

  describe "read_transacciones/1" do
    test "lee transacciones válidas desde archivo" do
      archivo = Path.join(@fixtures_path, "test_transacciones.csv")

      assert {:ok, transacciones} = CSVReader.read_transacciones(archivo)
      assert length(transacciones) == 3

      # Verificar primera transacción completa
      primera = List.first(transacciones)
      assert primera.id_transaccion == 1
      assert primera.timestamp == 1_754_937_004
      assert primera.moneda_origen == "USDT"
      assert primera.moneda_destino == "USDT"
      assert primera.monto == 100.5
      assert primera.cuenta_origen == "userA"
      assert primera.cuenta_destino == "userB"
      assert primera.tipo == "transferencia"
    end

    test "maneja campos vacíos correctamente en alta_cuenta" do
      archivo = Path.join(@fixtures_path, "test_transacciones.csv")

      assert {:ok, transacciones} = CSVReader.read_transacciones(archivo)

      # Transacción de alta_cuenta (tercera línea)
      alta_cuenta = Enum.at(transacciones, 2)
      assert alta_cuenta.moneda_destino == nil
      assert alta_cuenta.cuenta_destino == nil
      assert alta_cuenta.tipo == "alta_cuenta"
    end

    test "maneja archivos inexistentes" do
      assert {:error, :enoent} = CSVReader.read_transacciones("archivo_inexistente.csv")
    end

    test "retorna error para líneas malformadas" do
      archivo = Path.join(@fixtures_path, "invalid_transacciones.csv")

      assert {:error, 2} = CSVReader.read_transacciones(archivo)
    end

    test "usa archivo por defecto cuando no se especifica" do
      # Crear archivo temporal en directorio actual
      contenido = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;USDT;100.5;userA;userB;transferencia
      """
      File.write!("transacciones.csv", contenido)

      assert {:ok, transacciones} = CSVReader.read_transacciones()
      assert length(transacciones) == 1

      # Limpiar archivo temporal
      File.rm("transacciones.csv")
    end
  end

  describe "read_monedas/1" do
    test "lee monedas válidas desde archivo" do
      archivo = Path.join(@fixtures_path, "test_monedas.csv")

      assert {:ok, monedas} = CSVReader.read_monedas(archivo)
      assert length(monedas) == 3

      btc = List.first(monedas)
      assert btc.nombre_moneda == "BTC"
      assert btc.precio_usd == 45000.50
    end

    test "maneja archivos inexistentes" do
      assert {:error, :enoent} = CSVReader.read_monedas("archivo_inexistente.csv")
    end

    test "usa archivo por defecto cuando no se especifica" do
      # Crear archivo temporal en directorio actual
      contenido = """
      nombre_moneda;precio_usd
      TEST;123.45
      """
      File.write!("monedas.csv", contenido)

      assert {:ok, monedas} = CSVReader.read_monedas()
      assert length(monedas) == 1

      # Limpiar archivo temporal
      File.rm("monedas.csv")
    end
  end

  describe "parsing functions" do
    test "parse_integer maneja enteros válidos" do
      # Esta función es privada, pero la testearemos indirectamente
      archivo = Path.join(@fixtures_path, "test_transacciones.csv")
      {:ok, transacciones} = CSVReader.read_transacciones(archivo)

      primera = List.first(transacciones)
      assert is_integer(primera.id_transaccion)
      assert is_integer(primera.timestamp)
    end

    test "parse_float maneja números decimales válidos" do
      archivo = Path.join(@fixtures_path, "test_transacciones.csv")
      {:ok, transacciones} = CSVReader.read_transacciones(archivo)

      primera = List.first(transacciones)
      assert is_float(primera.monto)
      assert primera.monto == 100.5
    end

    test "parse_string maneja strings vacías" do
      archivo = Path.join(@fixtures_path, "test_transacciones.csv")
      {:ok, transacciones} = CSVReader.read_transacciones(archivo)

      # Verificar que los campos vacíos se convierten en nil
      alta_cuenta = Enum.at(transacciones, 2)
      assert alta_cuenta.moneda_destino == nil
    end

    test "maneja datos inválidos retornando error" do
      # Crear archivo con datos inválidos para números
      contenido = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      abc;def;USD;BTC;xyz;userA;userB;transferencia
      """

      archivo_temp = "temp_invalid_numbers.csv"
      File.write!(archivo_temp, contenido)

      assert {:error, 2} = CSVReader.read_transacciones(archivo_temp)

      # Limpiar
      File.rm(archivo_temp)
    end

    test "maneja números inválidos en monedas" do
      contenido = """
      nombre_moneda;precio_usd
      BTC;abc
      """

      archivo_temp = "temp_invalid_price.csv"
      File.write!(archivo_temp, contenido)

      assert {:error, 2} = CSVReader.read_monedas(archivo_temp)

      # Limpiar
      File.rm(archivo_temp)
    end
  end

  describe "validaciones con número de línea" do
    test "retorna error con número de línea para monto negativo" do
      archivo_error = Path.join(@fixtures_path, "error_monto_negativo.csv")

      assert {:error, 2} = CSVReader.read_transacciones(archivo_error)
    end

    test "retorna error con número de línea para ID inválido" do
      archivo_error = Path.join(@fixtures_path, "error_formato_id.csv")

      assert {:error, 3} = CSVReader.read_transacciones(archivo_error)
    end

    test "retorna error con número de línea para tipo inválido" do
      archivo_error = Path.join(@fixtures_path, "error_tipo_invalido.csv")

      assert {:error, 2} = CSVReader.read_transacciones(archivo_error)
    end

    test "retorna error con número de línea para moneda inexistente" do
      archivo_error = Path.join(@fixtures_path, "error_moneda_inexistente.csv")
      archivo_monedas = Path.join(@fixtures_path, "test_monedas.csv")

      assert {:error, 3} = CSVReader.read_and_validate_all(archivo_error, archivo_monedas)
    end

    test "valida correctamente archivo simple" do
      archivo_debug = Path.join(@fixtures_path, "debug_simple.csv")
      archivo_monedas = Path.join(@fixtures_path, "test_monedas.csv")

      assert {:ok, {transacciones, _monedas}} = CSVReader.read_and_validate_all(archivo_debug, archivo_monedas)
      assert length(transacciones) == 1
    end

    test "valida formato de número de campos incorrecto" do
      # Crear archivo temporal con campos incorrectos
      contenido = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;USDT;100.5;userA;extra_field;userB;transferencia
      """

      archivo_temp = "temp_campos_incorrectos.csv"
      File.write!(archivo_temp, contenido)

      assert {:error, 2} = CSVReader.read_transacciones(archivo_temp)

      # Limpiar
      File.rm(archivo_temp)
    end
  end
end
