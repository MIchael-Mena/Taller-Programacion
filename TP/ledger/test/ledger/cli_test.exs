defmodule Ledger.CLITest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  alias Ledger.CLI

  @fixtures_path Path.expand("test/fixtures", __DIR__ |> Path.dirname() |> Path.dirname())
  @test_transacciones_file Path.join(@fixtures_path, "test_transacciones_completo.csv")
  @test_monedas_file Path.join(@fixtures_path, "test_monedas.csv")
  @debug_simple_file Path.join(@fixtures_path, "debug_simple.csv")

  describe "main/1" do
    test "muestra mensaje de bienvenida sin argumentos" do
      output = capture_io(fn ->
        CLI.main([])
      end)

      assert output =~ "¡Bienvenido al sistema Ledger!"
      assert output =~ "Usa --help para ver las opciones disponibles."
    end

    test "muestra ayuda con --help" do
      output = capture_io(fn ->
        CLI.main(["--help"])
      end)

      assert output =~ "Ledger - Sistema de libros contables"
      assert output =~ "Uso: ledger <subcomando> [opciones]"
      assert output =~ "transacciones"
      assert output =~ "balance"
    end

    test "muestra ayuda con -h" do
      output = capture_io(fn ->
        CLI.main(["-h"])
      end)

      assert output =~ "Ledger - Sistema de libros contables"
    end

    test "muestra versión con --version" do
      output = capture_io(fn ->
        CLI.main(["--version"])
      end)

      assert output =~ "Ledger v"
    end

    test "muestra versión con -v" do
      output = capture_io(fn ->
        CLI.main(["-v"])
      end)

      assert output =~ "Ledger v"
    end

    test "maneja comando no reconocido" do
      output = capture_io(fn ->
        CLI.main(["comando_inexistente"])
      end)

      assert output =~ "Comando no reconocido: comando_inexistente"
      assert output =~ "Comandos disponibles: transacciones, balance"
    end
  end

  describe "comando transacciones" do
    test "lista todas las transacciones con archivo de test" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@debug_simple_file}", "-m=#{@test_monedas_file}"])
      end)

      # Verificar que contiene datos de transacción (sin header)
      assert output =~ "1;1754937004;USDT;USDT;100.5;userA;userB;transferencia"
    end

    test "filtra por cuenta origen" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@test_transacciones_file}", "-m=#{@test_monedas_file}", "-c1=userA"])
      end)

      assert output =~ "userA"
      refute output =~ "userB;;"  # No debe mostrar el swap de userB
    end

    test "filtra por cuenta destino" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@test_transacciones_file}", "-m=#{@test_monedas_file}", "-c2=userB"])
      end)

      assert output =~ "userB"
      refute output =~ "userB;;"  # No debe mostrar transacciones sin destino
    end

    test "muestra mensaje cuando no hay transacciones que coincidan" do
      archivo_test = Path.join(@fixtures_path, "debug_simple.csv")
      archivo_monedas = Path.join(@fixtures_path, "test_monedas.csv")

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_test}", "-m=#{archivo_monedas}", "-c1=usuario_inexistente"])
      end)

      assert output =~ "No se encontraron transacciones que coincidan con los filtros."
    end

    test "maneja error al leer archivo inexistente" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=archivo_inexistente.csv"])
      end)

      assert output =~ "Error al leer archivo_inexistente.csv"
    end

    test "guarda salida en archivo cuando se especifica --o" do
      archivo_salida = "test_output.csv"

      # Asegurar que no existe el archivo
      File.rm(archivo_salida)

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@debug_simple_file}", "-m=#{@test_monedas_file}", "-o=#{archivo_salida}"])
      end)

      assert output =~ "Transacciones guardadas en #{archivo_salida}"
      assert File.exists?(archivo_salida)

      # Verificar contenido del archivo
      contenido = File.read!(archivo_salida)
      # Verificar que contiene datos de transacción (sin header)
      assert contenido =~ "1;1754937004;USDT;USDT;100.5;userA;userB;transferencia"

      # Limpiar
      File.rm(archivo_salida)
    end

    test "maneja error al escribir archivo de salida" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@debug_simple_file}", "-m=#{@test_monedas_file}", "-o=/directorio_inexistente/salida.csv"])
      end)

      assert output =~ "Error al escribir en /directorio_inexistente/salida.csv"
    end
  end

  describe "comando balance" do
    setup do
      # Crear archivo de transacciones para tests de balance
      contenido_transacciones = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;USDT;100.50;userA;userB;transferencia
      2;1755541804;BTC;;50000;userC;;alta_cuenta
      3;1756751404;USDT;USDT;25.00;userB;userA;transferencia
      4;1757751404;ETH;BTC;5.0;userA;;swap
      """

      contenido_monedas = """
      nombre_moneda;precio_usd
      BTC;55000.0
      USDT;1.0
      ETH;3000.0
      """

      archivo_transacciones = "test_balance_transacciones.csv"
      archivo_monedas = "monedas.csv"

      File.write!(archivo_transacciones, contenido_transacciones)
      File.write!(archivo_monedas, contenido_monedas)

      on_exit(fn ->
        File.rm(archivo_transacciones)
        File.rm(archivo_monedas)
      end)

      %{archivo_transacciones: archivo_transacciones}
    end

    test "muestra error cuando falta flag -c1", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-t=#{archivo}"])
      end)

      assert output =~ "Error: El flag -c1 es obligatorio para el comando balance"
    end

    test "calcula balance en todas las monedas para una cuenta", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{archivo}"])
      end)

      # userA: -100.50 USDT (envió) + 25.00 USDT (recibió) - 5.0 ETH (swap) + 5.0 BTC (swap)
      assert output =~ "USDT=-75.500000"
      assert output =~ "ETH=-5.000000"
      assert output =~ "BTC=5.000000"
    end

    test "calcula balance para userB", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userB", "-t=#{archivo}"])
      end)

      # userB: +100.50 USDT (recibió) - 25.00 USDT (envió) = 75.50 USDT
      assert output =~ "USDT=75.500000"
    end

    test "calcula balance para userC", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userC", "-t=#{archivo}"])
      end)

      # userC: +50000 BTC (alta_cuenta)
      assert output =~ "BTC=50000.000000"
    end

    test "convierte balance a moneda específica", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{archivo}", "-m=BTC"])
      end)

      # Verificar que el output es un solo número en BTC
      lines = String.split(output, "\n", trim: true)
      assert length(lines) == 1
      assert hd(lines) =~ ~r/BTC=-?\d+\.\d{6}/
    end

    test "maneja cuenta inexistente", %{archivo_transacciones: archivo} do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userXXX", "-t=#{archivo}"])
      end)

      # No debería haber salida para cuenta inexistente
      assert String.trim(output) == ""
    end

    test "maneja errores de archivo inexistente" do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=archivo_inexistente.csv"])
      end)

      assert output =~ "Error al calcular balance:"
    end

    test "maneja correctamente balances negativos" do
      # Crear archivo con transacciones que generan balance negativo
      contenido_transacciones = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;;100.0;userA;;alta_cuenta
      2;1755541804;USDT;USDT;150.0;userA;userB;transferencia
      """

      archivo_transacciones = "test_balance_negativo.csv"
      File.write!(archivo_transacciones, contenido_transacciones)

      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{archivo_transacciones}"])
      end)

      # userA: +100.0 USDT (alta) - 150.0 USDT (transferencia) = -50.0 USDT
      assert output =~ "USDT=-50.000000"

      File.rm!(archivo_transacciones)
    end
  end

  describe "filtering functions" do
    setup do
      # Crear datos de test en memoria
      transacciones = [
        %Ledger.CSVReader.Transaccion{
          id_transaccion: 1,
          cuenta_origen: "userA",
          cuenta_destino: "userB",
          tipo: "transferencia"
        },
        %Ledger.CSVReader.Transaccion{
          id_transaccion: 2,
          cuenta_origen: "userB",
          cuenta_destino: "userC",
          tipo: "transferencia"
        },
        %Ledger.CSVReader.Transaccion{
          id_transaccion: 3,
          cuenta_origen: "userA",
          cuenta_destino: "userC",
          tipo: "swap"
        }
      ]

      {:ok, transacciones: transacciones}
    end

    test "filtrar por c1 y c2 combinados" do
      # Crear archivo con datos específicos para esta prueba
      contenido = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;USDT;100.5;userA;userB;transferencia
      2;1754937104;BTC;BTC;0.5;userA;userC;transferencia
      3;1754937204;ETH;ETH;1.0;userB;userC;transferencia
      """

      archivo_temp = "temp_test_combined.csv"
      File.write!(archivo_temp, contenido)

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_temp}", "-m=#{@test_monedas_file}", "-c1=userA", "-c2=userB"])
      end)

      assert output =~ "userA;userB"
      refute output =~ "userA;userC"
      refute output =~ "userB;userC"

      # Limpiar
      File.rm(archivo_temp)
    end
  end

  describe "format_transacciones/1" do
    test "formatea transacciones correctamente con todos los campos" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@debug_simple_file}", "-m=#{@test_monedas_file}"])
      end)

      lines = String.split(output, "\n", trim: true)
      primera_linea = List.first(lines)

      # Verificar que la primera línea es datos (no header)
      assert primera_linea == "1;1754937004;USDT;USDT;100.5;userA;userB;transferencia"

      # Verificar que hay al menos una línea de datos
      assert length(lines) >= 1
    end

    test "maneja campos nil correctamente en formato" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@test_transacciones_file}", "-m=#{@test_monedas_file}"])
      end)

      # Debe manejar campos vacíos sin errores y mostrar ;; para campos nil consecutivos
      assert output =~ ";;" # Campos vacíos consecutivos en alta_cuenta y swap
    end
  end

  describe "parse_args/1" do
    test "parsea argumentos válidos correctamente" do
      # Esta función es privada, la testeamos indirectamente
      output = capture_io(fn ->
        CLI.main(["transacciones", "-c1=test", "-c2=test2", "-t=test.csv"])
      end)

      # Si no hay errores de parsing, el comando debe proceder
      assert output =~ "Error al leer test.csv" # Archivo no existe, pero parsing fue exitoso
    end

    test "maneja múltiples flags simultáneamente" do
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{@test_transacciones_file}", "-m=#{@test_monedas_file}", "-c1=userA", "-c2=userB"])
      end)

      # Debe procesar todos los flags sin error
      refute output =~ "Error:"
    end
  end

  describe "manejo de errores con formato {:error, nro_linea}" do
    test "muestra error en formato correcto para monto negativo" do
      archivo_error = Path.join(@fixtures_path, "error_monto_negativo.csv")

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_error}", "-m=#{@test_monedas_file}"])
      end)

      assert output =~ "{:error, 2}"
    end

    test "muestra error en formato correcto para ID inválido" do
      archivo_error = Path.join(@fixtures_path, "error_formato_id.csv")

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_error}", "-m=#{@test_monedas_file}"])
      end)

      assert output =~ "{:error, 3}"
    end

    test "muestra error en formato correcto para tipo inválido" do
      archivo_error = Path.join(@fixtures_path, "error_tipo_invalido.csv")

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_error}", "-m=#{@test_monedas_file}"])
      end)

      assert output =~ "{:error, 2}"
    end

    test "muestra error en formato correcto para moneda inexistente" do
      archivo_error = Path.join(@fixtures_path, "error_moneda_inexistente.csv")

      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_error}", "-m=#{@test_monedas_file}"])
      end)

      assert output =~ "{:error, 3}"
    end
  end

  describe "opciones de archivos" do
    test "comando transacciones valida correctamente monedas personalizadas" do
      # Crear archivo de monedas personalizado en directorio actual
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      # Sobrescribir monedas.csv temporalmente con moneda personalizada
      contenido_monedas = """
      nombre_moneda;precio_usd
      CUSTOM;1000.0
      """
      File.write!("monedas.csv", contenido_monedas)

      # Crear archivo de transacciones que requiere la moneda CUSTOM
      archivo_transacciones_custom = "test_transacciones_custom.csv"
      contenido_transacciones = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;CUSTOM;CUSTOM;100.0;userA;userB;transferencia
      """
      File.write!(archivo_transacciones_custom, contenido_transacciones)

      # Si las monedas están definidas correctamente, debería funcionar
      output = capture_io(fn ->
        CLI.main(["transacciones", "-t=#{archivo_transacciones_custom}"])
      end)

      assert output =~ "CUSTOM"
      assert output =~ "userA;userB"

      # Limpiar archivos temporales y restaurar monedas.csv
      File.rm!(archivo_transacciones_custom)
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end

    test "comando balance usa -m para especificar moneda de conversión" do
      # Crear archivo de monedas en el directorio actual para que sea encontrado por defecto
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      # Sobrescribir monedas.csv temporalmente con precios específicos
      contenido_monedas = """
      nombre_moneda;precio_usd
      TESTCOIN;2000.0
      USD;1.0
      """
      File.write!("monedas.csv", contenido_monedas)

      # Crear archivo de transacciones
      archivo_transacciones_custom = "test_transacciones_balance.csv"
      contenido_transacciones = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USD;;2000.0;userA;;alta_cuenta
      """
      File.write!(archivo_transacciones_custom, contenido_transacciones)

      # Balance convertido a TESTCOIN (2000 USD / 2000 = 1.0 TESTCOIN)
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{archivo_transacciones_custom}", "-m=TESTCOIN"])
      end)

      # Debería mostrar balance convertido a TESTCOIN
      assert output =~ "TESTCOIN=1.000000"

      # Limpiar archivos temporales y restaurar monedas.csv
      File.rm!(archivo_transacciones_custom)
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end
  end

  describe "manejo de errores en comando balance" do
    test "balance detecta monto negativo y retorna {:error, nro_linea}" do
      # Crear archivo temporal con monto negativo
      archivo_error = "test_balance_monto_negativo.csv"
      contenido = """
      id_transaccion;timestamp;moneda_origen;moneda_destino;monto;cuenta_origen;cuenta_destino;tipo
      1;1754937004;USDT;;-100.5;userA;;alta_cuenta
      """
      File.write!(archivo_error, contenido)

      # Necesitamos un archivo de monedas válido para que el test funcione
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      # Crear monedas.csv temporalmente
      File.write!("monedas.csv", "nombre_moneda;precio_usd\nUSDT;1.0\n")

      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{archivo_error}"])
      end)

      assert output =~ "{:error, 2}"

      # Limpiar
      File.rm!(archivo_error)
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end

    test "balance detecta moneda inexistente y retorna {:error, nro_linea}" do
      # Crear archivo de monedas que no incluye la moneda del archivo de error
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      # Crear monedas.csv sin la moneda INEXISTENTE
      File.write!("monedas.csv", "nombre_moneda;precio_usd\nUSDT;1.0\nBTC;55000.0\n")

      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{Path.join(@fixtures_path, "error_moneda_inexistente.csv")}"])
      end)

      assert output =~ "{:error, 3}"

      # Restaurar monedas.csv
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end

    test "balance detecta ID inválido y retorna {:error, nro_linea}" do
      # Crear monedas.csv temporalmente
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      File.write!("monedas.csv", "nombre_moneda;precio_usd\nUSDT;1.0\n")

      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{Path.join(@fixtures_path, "error_formato_id.csv")}"])
      end)

      assert output =~ "{:error, 3}"

      # Restaurar monedas.csv
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end

    test "balance detecta tipo de transacción inválido y retorna {:error, nro_linea}" do
      # Crear monedas.csv temporalmente
      archivo_monedas_backup = if File.exists?("monedas.csv") do
        File.read!("monedas.csv")
      else
        nil
      end

      File.write!("monedas.csv", "nombre_moneda;precio_usd\nUSDT;1.0\n")

      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=#{Path.join(@fixtures_path, "error_tipo_invalido.csv")}"])
      end)

      assert output =~ "{:error, 2}"

      # Restaurar monedas.csv
      if archivo_monedas_backup do
        File.write!("monedas.csv", archivo_monedas_backup)
      else
        File.rm!("monedas.csv")
      end
    end

    test "balance maneja archivo de transacciones inexistente" do
      output = capture_io(fn ->
        CLI.main(["balance", "-c1=userA", "-t=archivo_inexistente.csv"])
      end)

      assert output =~ "Error al calcular balance: enoent"
    end
  end
end
