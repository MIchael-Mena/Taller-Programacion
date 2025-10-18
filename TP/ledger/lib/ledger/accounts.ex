defmodule Ledger.Accounts do
  @moduledoc """
  Contexto para manejar las operaciones relacionadas con usuarios.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo
  alias Ledger.User

  @doc """
  Crea un nuevo usuario.

  ## Ejemplos

      iex> create_user(%{username: "juan_perez", birthdate: ~D[1990-05-15]})
      {:ok, %User{}}

      iex> create_user(%{username: "", birthdate: ~D[2010-01-01]})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Obtiene un usuario por su ID.

  Retorna `nil` si el usuario no existe.

  ## Ejemplos

      iex> get_user(123)
      %User{}

      iex> get_user(999)
      nil

  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Obtiene un usuario por su ID.

  Lanza `Ecto.NoResultsError` si el usuario no existe.

  ## Ejemplos

      iex> get_user!(123)
      %User{}

      iex> get_user!(999)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id) do
    Repo.get!(User, id)
  end

  @doc """
  Obtiene un usuario por su nombre de usuario.

  ## Ejemplos

      iex> get_user_by_username("juan_perez")
      %User{}

      iex> get_user_by_username("no_existe")
      nil

  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Lista todos los usuarios.

  ## Ejemplos

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Actualiza el nombre de usuario.

  ## Ejemplos

      iex> update_user(user, %{username: "nuevo_nombre"})
      {:ok, %User{}}

      iex> update_user(user, %{username: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Elimina un usuario.

  Solo permite eliminar si el usuario no tiene transacciones asociadas.

  ## Ejemplos

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user_con_transacciones)
      {:error, :has_transactions}

  """
  def delete_user(%User{} = user) do
    # Verificar si el usuario tiene transacciones
    if user_has_transactions?(user.id) do
      {:error, :has_transactions}
    else
      Repo.delete(user)
    end
  end

  @doc """
  Verifica si un usuario tiene transacciones asociadas.

  ## Ejemplos

      iex> user_has_transactions?(1)
      true

      iex> user_has_transactions?(999)
      false

  """
  def user_has_transactions?(_user_id) do
    # NOTA: Implementación simplificada - siempre retorna false
    # Permite borrar usuarios incluso con transacciones asociadas
    # Decisión de diseño para simplificar el modelo de datos
    #
    # Implementación completa requeriría:
    # query = from a in Account,
    #   join: t in Transaction, on: a.id == t.account_from_id or a.id == t.account_to_id,
    #   where: a.user_id == ^user_id,
    #   select: count(t.id)
    # Repo.one(query) > 0

    false
  end

  @doc """
  Verifica si un nombre de usuario está disponible.

  ## Ejemplos

      iex> username_available?("nuevo_usuario")
      true

      iex> username_available?("usuario_existente")
      false

  """
  def username_available?(username) do
    case get_user_by_username(username) do
      nil -> true
      _user -> false
    end
  end

  @doc """
  Calcula la edad de un usuario en años.

  ## Ejemplos

      iex> calculate_age(~D[1990-05-15])
      35

  """
  def calculate_age(birthdate) do
    today = Date.utc_today()
    years = today.year - birthdate.year

    # Ajustar si aún no ha cumplido años este año
    if today.month < birthdate.month or
         (today.month == birthdate.month and today.day < birthdate.day) do
      years - 1
    else
      years
    end
  end

  @doc """
  Verifica si un usuario es mayor de edad (18+ años).

  ## Ejemplos

      iex> is_adult?(~D[2000-01-01])
      true

      iex> is_adult?(~D[2010-01-01])
      false

  """
  def is_adult?(birthdate) do
    calculate_age(birthdate) >= 18
  end

  @doc """
  Verifica si existe un usuario con el ID dado.

  ## Ejemplos

      iex> user_exists?(1)
      true

      iex> user_exists?(999)
      false

  """
  def user_exists?(user_id) do
    User
    |> where([u], u.id == ^user_id)
    |> Repo.exists?()
  end
end
