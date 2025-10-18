defmodule Ledger.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :birthdate, :date
    field :inserted_at, :naive_datetime
    field :updated_at, :naive_datetime
  end

  @doc """
  Crea un changeset para validar los datos del usuario.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :birthdate])
    |> validate_required([:username, :birthdate])
    |> validate_unique_username()
    |> validate_age()
    |> put_timestamps()
  end

  @doc """
  Crea un changeset para actualizar el nombre de usuario.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> validate_required([:username])
    |> validate_unique_username()
    |> validate_username_changed(user.username)
    |> update_timestamp()
  end

  # Valida que el nombre de usuario sea único
  defp validate_unique_username(changeset) do
    changeset
    |> unique_constraint(:username, name: :users_username_index)
  end

  # Valida que el usuario tenga más de 18 años
  defp validate_age(changeset) do
    case get_field(changeset, :birthdate) do
      nil ->
        changeset

      birthdate ->
        today = Date.utc_today()
        age = Date.diff(today, birthdate) / 365.25

        if age >= 18 do
          changeset
        else
          add_error(changeset, :birthdate, "El usuario debe tener más de 18 años")
        end
    end
  end

  # Valida que el nombre de usuario sea distinto al anterior
  defp validate_username_changed(changeset, old_username) do
    new_username = get_field(changeset, :username)

    if new_username && new_username == old_username do
      add_error(changeset, :username, "El nuevo nombre debe ser distinto al anterior")
    else
      changeset
    end
  end

  # Agrega timestamps en la creación
  defp put_timestamps(changeset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    changeset
    |> put_change(:inserted_at, now)
    |> put_change(:updated_at, now)
  end

  # Actualiza el timestamp de modificación
  defp update_timestamp(changeset) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    put_change(changeset, :updated_at, now)
  end
end
