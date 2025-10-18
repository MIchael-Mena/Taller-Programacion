defmodule Ledger.CLI.Currencies do
  @moduledoc """
  Módulo para manejar los comandos CLI relacionados con monedas.
  """

  alias Ledger.Currencies

  @doc """
  Crea una nueva moneda.

  ## Parámetros
  - `-n` o `--name`: Nombre de la moneda en mayúsculas (3-4 letras) (requerido)
  - `-p` o `--price`: Precio en dólares (requerido, >= 0)

  ## Ejemplos
      ./ledger crear_moneda -n=BTC -p=55000.0
      ./ledger crear_moneda --name=USDT --price=1.0
  """
  def crear_moneda(args) do
    with {:ok, name} <- get_arg(args, ["-n", "--name"], "nombre de moneda"),
         {:ok, price_str} <- get_arg(args, ["-p", "--price"], "precio"),
         {:ok, price} <- parse_float(price_str, "precio"),
         :ok <- validate_name_format(name),
         {:ok, currency} <- Currencies.create_currency(%{name: name, price_usd: price}) do
      IO.puts("""
      Moneda creada exitosamente:
        ID: #{currency.id}
        Nombre: #{currency.name}
        Precio (USD): $#{currency.price_usd}
        Creada el: #{currency.inserted_at}
      """)

      {:ok, currency}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        error_msg = format_changeset_errors(errors)
        print_error("crear_moneda", error_msg)

      {:error, reason} ->
        print_error("crear_moneda", reason)
    end
  end

  @doc """
  Edita el precio de una moneda.

  ## Parámetros
  - `-id`: ID de la moneda (requerido)
  - `-p` o `--price`: Nuevo precio en dólares (requerido, >= 0)

  ## Ejemplos
      ./ledger editar_moneda -id=1 -p=56000.0
      ./ledger editar_moneda -id=2 --price=1.01
  """
  def editar_moneda(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de moneda"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, price_str} <- get_arg(args, ["-p", "--price"], "nuevo precio"),
         {:ok, price} <- parse_float(price_str, "precio"),
         {:ok, currency} <- get_currency(id),
         {:ok, updated_currency} <- Currencies.update_currency(currency, %{price_usd: price}) do
      IO.puts("""
      Moneda actualizada exitosamente:
        ID: #{updated_currency.id}
        Nombre: #{updated_currency.name}
        Nuevo precio (USD): $#{updated_currency.price_usd}
        Actualizada el: #{updated_currency.updated_at}
      """)

      {:ok, updated_currency}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        error_msg = format_changeset_errors(errors)
        print_error("editar_moneda", error_msg)

      {:error, reason} ->
        print_error("editar_moneda", reason)
    end
  end

  @doc """
  Elimina una moneda.

  ## Parámetros
  - `-id`: ID de la moneda (requerido)

  ## Ejemplos
      ./ledger borrar_moneda -id=1
  """
  def borrar_moneda(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de moneda"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, currency} <- get_currency(id),
         {:ok, deleted_currency} <- Currencies.delete_currency(currency) do
      IO.puts("""
      Moneda eliminada exitosamente:
        ID: #{deleted_currency.id}
        Nombre: #{deleted_currency.name}
        Precio (USD): $#{deleted_currency.price_usd}
      """)

      {:ok, deleted_currency}
    else
      {:error, :has_transactions} ->
        print_error("borrar_moneda", "La moneda tiene transacciones asociadas y no puede ser eliminada")

      {:error, reason} ->
        print_error("borrar_moneda", reason)
    end
  end

  @doc """
  Muestra la información de una moneda.

  ## Parámetros
  - `-id`: ID de la moneda (requerido)

  ## Ejemplos
      ./ledger ver_moneda -id=1
  """
  def ver_moneda(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de moneda"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, currency} <- get_currency(id) do
      IO.puts("""
      ========================================
      INFORMACIÓN DE LA MONEDA
      ========================================
      ID:                 #{currency.id}
      Nombre:             #{currency.name}
      Precio (USD):       $#{currency.price_usd}
      Fecha de creación:  #{currency.inserted_at}
      Última actualización: #{currency.updated_at}
      ========================================
      """)

      {:ok, currency}
    else
      {:error, reason} ->
        print_error("ver_moneda", reason)
    end
  end

  # ========== Funciones auxiliares ==========

  defp get_arg(args, flags, field_name) when is_list(flags) do
    result =
      Enum.find_value(flags, fn flag ->
        case Enum.find(args, &String.starts_with?(&1, "#{flag}=")) do
          nil -> nil
          arg -> String.split(arg, "=", parts: 2) |> List.last()
        end
      end)

    case result do
      nil -> {:error, "Falta el parámetro: #{field_name}"}
      "" -> {:error, "El parámetro #{field_name} no puede estar vacío"}
      value -> {:ok, value}
    end
  end

  defp parse_integer(str, field_name) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "El #{field_name} debe ser un número entero válido"}
    end
  end

  defp parse_float(str, field_name) do
    case Float.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "El #{field_name} debe ser un número válido"}
    end
  end

  defp validate_name_format(name) do
    if Currencies.valid_currency_name?(name) do
      :ok
    else
      {:error, "El nombre debe estar en mayúsculas y tener entre 3 y 4 letras"}
    end
  end

  defp get_currency(id) do
    case Currencies.get_currency(id) do
      nil -> {:error, "Moneda con ID #{id} no encontrada"}
      currency -> {:ok, currency}
    end
  end

  defp format_changeset_errors(errors) do
    errors
    |> Enum.map(fn {field, {msg, _opts}} -> "#{field}: #{msg}" end)
    |> Enum.join(", ")
  end

  defp print_error(command, message) do
    IO.puts("{:error, #{command}: \"#{message}\"}")
    {:error, message}
  end
end
