defmodule Ledger.AccountsTest do
  use ExUnit.Case, async: true

  alias Ledger.Accounts
  alias Ledger.Repo
  alias Ledger.User

  setup do
    # Limpia la base de datos antes de cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create_user/1" do
    test "crea un usuario válido" do
      attrs = %{
        username: "juan_perez",
        birthdate: ~D[1990-05-15]
      }

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.username == "juan_perez"
      assert user.birthdate == ~D[1990-05-15]
      assert user.id != nil
      assert user.inserted_at != nil
      assert user.updated_at != nil
    end

    test "no permite crear usuario sin nombre" do
      attrs = %{birthdate: ~D[1990-05-15]}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{username: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite crear usuario sin fecha de nacimiento" do
      attrs = %{username: "maria_gomez"}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{birthdate: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite crear usuario menor de 18 años" do
      today = Date.utc_today()
      birthdate = Date.add(today, -365 * 17)  # 17 años

      attrs = %{
        username: "menor_edad",
        birthdate: birthdate
      }

      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{birthdate: ["El usuario debe tener más de 18 años"]} = errors_on(changeset)
    end

    test "no permite nombres de usuario duplicados" do
      attrs = %{username: "duplicado", birthdate: ~D[1990-01-01]}

      assert {:ok, _user1} = Accounts.create_user(attrs)
      assert {:error, changeset} = Accounts.create_user(attrs)

      # El error específico puede variar según la configuración
      assert changeset.valid? == false
    end
  end

  describe "get_user/1" do
    test "obtiene un usuario existente por ID" do
      {:ok, created_user} = Accounts.create_user(%{
        username: "test_user",
        birthdate: ~D[1990-01-01]
      })

      user = Accounts.get_user(created_user.id)
      assert user.id == created_user.id
      assert user.username == "test_user"
    end

    test "retorna nil para ID inexistente" do
      assert Accounts.get_user(99999) == nil
    end
  end

  describe "get_user_by_username/1" do
    test "obtiene un usuario por nombre de usuario" do
      {:ok, _created_user} = Accounts.create_user(%{
        username: "find_me",
        birthdate: ~D[1990-01-01]
      })

      user = Accounts.get_user_by_username("find_me")
      assert user.username == "find_me"
    end

    test "retorna nil para nombre de usuario inexistente" do
      assert Accounts.get_user_by_username("no_existe") == nil
    end
  end

  describe "list_users/0" do
    test "lista todos los usuarios" do
      # Inicialmente vacío
      assert Accounts.list_users() == []

      # Crear algunos usuarios
      {:ok, _user1} = Accounts.create_user(%{username: "user1", birthdate: ~D[1990-01-01]})
      {:ok, _user2} = Accounts.create_user(%{username: "user2", birthdate: ~D[1985-06-15]})

      users = Accounts.list_users()
      assert length(users) == 2
    end
  end

  describe "update_user/2" do
    test "actualiza el nombre de usuario correctamente" do
      {:ok, user} = Accounts.create_user(%{
        username: "original",
        birthdate: ~D[1990-01-01]
      })

      assert {:ok, updated_user} = Accounts.update_user(user, %{username: "nuevo_nombre"})
      assert updated_user.username == "nuevo_nombre"
      assert updated_user.id == user.id
    end

    test "no permite cambiar a un nombre igual al actual" do
      {:ok, user} = Accounts.create_user(%{
        username: "mismo_nombre",
        birthdate: ~D[1990-01-01]
      })

      assert {:error, changeset} = Accounts.update_user(user, %{username: "mismo_nombre"})
      assert %{username: ["El nuevo nombre debe ser distinto al anterior"]} = errors_on(changeset)
    end

    test "no permite nombre de usuario vacío" do
      {:ok, user} = Accounts.create_user(%{
        username: "test",
        birthdate: ~D[1990-01-01]
      })

      assert {:error, changeset} = Accounts.update_user(user, %{username: ""})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :username)
      assert "can't be blank" in errors.username
    end
  end

  describe "delete_user/1" do
    test "elimina un usuario sin transacciones" do
      {:ok, user} = Accounts.create_user(%{
        username: "to_delete",
        birthdate: ~D[1990-01-01]
      })

      assert {:ok, deleted_user} = Accounts.delete_user(user)
      assert deleted_user.id == user.id
      assert Accounts.get_user(user.id) == nil
    end

    # Este test pasará cuando se implemente la tabla de transacciones
    # test "no permite eliminar usuario con transacciones" do
    #   {:ok, user} = Accounts.create_user(%{
    #     username: "with_transactions",
    #     birthdate: ~D[1990-01-01]
    #   })
    #   # Crear una transacción asociada...
    #   assert {:error, :has_transactions} = Accounts.delete_user(user)
    # end
  end

  describe "username_available?/1" do
    test "retorna true para nombre disponible" do
      assert Accounts.username_available?("disponible") == true
    end

    test "retorna false para nombre en uso" do
      {:ok, _user} = Accounts.create_user(%{
        username: "en_uso",
        birthdate: ~D[1990-01-01]
      })

      assert Accounts.username_available?("en_uso") == false
    end
  end

  describe "calculate_age/1" do
    test "calcula la edad correctamente" do
      # Persona nacida hace exactamente 30 años
      birthdate = Date.add(Date.utc_today(), -365 * 30)
      age = Accounts.calculate_age(birthdate)
      assert age >= 29 && age <= 30  # Margen por años bisiestos
    end

    test "ajusta si aún no ha cumplido años este año" do
      today = Date.utc_today()
      # Nacido el día de mañana hace 20 años
      birthdate = %{today | year: today.year - 20, day: min(today.day + 1, 28)}
      age = Accounts.calculate_age(birthdate)
      assert age == 19  # Aún no ha cumplido 20
    end
  end

  describe "is_adult?/1" do
    test "retorna true para mayor de 18" do
      birthdate = Date.add(Date.utc_today(), -365 * 25)
      assert Accounts.is_adult?(birthdate) == true
    end

    test "retorna false para menor de 18" do
      birthdate = Date.add(Date.utc_today(), -365 * 15)
      assert Accounts.is_adult?(birthdate) == false
    end

    test "retorna true para exactamente 18 años" do
      today = Date.utc_today()
      # Crear fecha de nacimiento hace exactamente 18 años y 1 día
      birthdate = %{today | year: today.year - 18} |> Date.add(-1)
      assert Accounts.is_adult?(birthdate) == true
    end
  end

  # Helper para extraer errores de un changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
