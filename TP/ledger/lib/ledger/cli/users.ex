defmodule Ledger.CLI.Users do
  @moduledoc """
  Módulo para manejar los comandos CLI relacionados con usuarios.
  """

  alias Ledger.Accounts

  @doc """
  Crea un nuevo usuario.

  ## Parámetros
  - `-n` o `--name`: Nombre de usuario (requerido)
  - `-b` o `--birthdate`: Fecha de nacimiento en formato YYYY-MM-DD (requerido)

  ## Ejemplos
      ./ledger crear_usuario -n=juan_perez -b=1990-05-15
      ./ledger crear_usuario --name=maria_gomez --birthdate=1985-12-20
  """
  def crear_usuario(args) do
    with {:ok, username} <- get_arg(args, ["-n", "--name"], "nombre de usuario"),
         {:ok, birthdate_str} <- get_arg(args, ["-b", "--birthdate"], "fecha de nacimiento"),
         {:ok, birthdate} <- parse_date(birthdate_str),
         :ok <- validate_adult(birthdate),
         {:ok, user} <- Accounts.create_user(%{username: username, birthdate: birthdate}) do
      IO.puts("""
      Usuario creado exitosamente:
        ID: #{user.id}
        Nombre de usuario: #{user.username}
        Fecha de nacimiento: #{user.birthdate}
        Creado el: #{user.inserted_at}
      """)

      {:ok, user}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        error_msg = format_changeset_errors(errors)
        print_error("crear_usuario", error_msg)

      {:error, reason} ->
        print_error("crear_usuario", reason)
    end
  end

  @doc """
  Edita el nombre de usuario.

  ## Parámetros
  - `-id`: ID del usuario (requerido)
  - `-n` o `--name`: Nuevo nombre de usuario (requerido)

  ## Ejemplos
      ./ledger editar_usuario -id=1 -n=nuevo_nombre
      ./ledger editar_usuario -id=5 --name=otro_nombre
  """
  def editar_usuario(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de usuario"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, new_username} <- get_arg(args, ["-n", "--name"], "nuevo nombre de usuario"),
         {:ok, user} <- get_user(id),
         {:ok, updated_user} <- Accounts.update_user(user, %{username: new_username}) do
      IO.puts("""
      Usuario actualizado exitosamente:
        ID: #{updated_user.id}
        Nombre de usuario: #{updated_user.username}
        Actualizado el: #{updated_user.updated_at}
      """)

      {:ok, updated_user}
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        error_msg = format_changeset_errors(errors)
        print_error("editar_usuario", error_msg)

      {:error, reason} ->
        print_error("editar_usuario", reason)
    end
  end

  @doc """
  Elimina un usuario.

  ## Parámetros
  - `-id`: ID del usuario (requerido)

  ## Ejemplos
      ./ledger borrar_usuario -id=1
  """
  def borrar_usuario(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de usuario"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, user} <- get_user(id),
         {:ok, deleted_user} <- Accounts.delete_user(user) do
      IO.puts("""
      Usuario eliminado exitosamente:
        ID: #{deleted_user.id}
        Nombre de usuario: #{deleted_user.username}
      """)

      {:ok, deleted_user}
    else
      {:error, :has_transactions} ->
        print_error("borrar_usuario", "El usuario tiene transacciones asociadas y no puede ser eliminado")

      {:error, reason} ->
        print_error("borrar_usuario", reason)
    end
  end

  @doc """
  Muestra la información de un usuario.

  ## Parámetros
  - `-id`: ID del usuario (requerido)

  ## Ejemplos
      ./ledger ver_usuario -id=1
  """
  def ver_usuario(args) do
    with {:ok, id_str} <- get_arg(args, ["-id"], "id de usuario"),
         {:ok, id} <- parse_integer(id_str, "id"),
         {:ok, user} <- get_user(id) do
      age = Accounts.calculate_age(user.birthdate)

      IO.puts("""
      ========================================
      INFORMACIÓN DEL USUARIO
      ========================================
      ID:                 #{user.id}
      Nombre de usuario:  #{user.username}
      Fecha de nacimiento: #{user.birthdate}
      Edad:               #{age} años
      Cuenta creada:      #{user.inserted_at}
      Última actualización: #{user.updated_at}
      ========================================
      """)

      {:ok, user}
    else
      {:error, reason} ->
        print_error("ver_usuario", reason)
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

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        {:ok, date}

      {:error, _} ->
        {:error, "Formato de fecha inválido. Use YYYY-MM-DD (ej: 1990-05-15)"}
    end
  end

  defp parse_integer(str, field_name) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> {:error, "El #{field_name} debe ser un número entero válido"}
    end
  end

  defp validate_adult(birthdate) do
    if Accounts.is_adult?(birthdate) do
      :ok
    else
      age = Accounts.calculate_age(birthdate)
      {:error, "El usuario debe tener al menos 18 años. Edad actual: #{age} años"}
    end
  end

  defp get_user(id) do
    case Accounts.get_user(id) do
      nil -> {:error, "Usuario con ID #{id} no encontrado"}
      user -> {:ok, user}
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
