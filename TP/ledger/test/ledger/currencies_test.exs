defmodule Ledger.CurrenciesTest do
  use ExUnit.Case, async: true

  alias Ledger.Currencies
  alias Ledger.Repo
  alias Ledger.Currency

  setup do
    # Limpia la base de datos antes de cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok
  end

  describe "create_currency/1" do
    test "crea una moneda válida" do
      attrs = %{
        name: "BTC",
        price_usd: 55000.0
      }

      assert {:ok, %Currency{} = currency} = Currencies.create_currency(attrs)
      assert currency.name == "BTC"
      assert currency.price_usd == 55000.0
      assert currency.id != nil
      assert currency.inserted_at != nil
      assert currency.updated_at != nil
    end

    test "crea una moneda con nombre de 3 letras" do
      attrs = %{name: "ETH", price_usd: 3000.0}
      assert {:ok, currency} = Currencies.create_currency(attrs)
      assert currency.name == "ETH"
    end

    test "crea una moneda con nombre de 4 letras" do
      attrs = %{name: "USDT", price_usd: 1.0}
      assert {:ok, currency} = Currencies.create_currency(attrs)
      assert currency.name == "USDT"
    end

    test "crea una moneda con precio 0" do
      attrs = %{name: "FREE", price_usd: 0.0}
      assert {:ok, currency} = Currencies.create_currency(attrs)
      assert currency.price_usd == 0.0
    end

    test "no permite crear moneda sin nombre" do
      attrs = %{price_usd: 1000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite crear moneda sin precio" do
      attrs = %{name: "BTC"}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{price_usd: ["can't be blank"]} = errors_on(changeset)
    end

    test "no permite nombre en minúsculas" do
      attrs = %{name: "btc", price_usd: 55000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: [_]} = errors_on(changeset)
    end

    test "no permite nombre en mayúsculas y minúsculas mezcladas" do
      attrs = %{name: "Btc", price_usd: 55000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: [_]} = errors_on(changeset)
    end

    test "no permite nombre con menos de 3 letras" do
      attrs = %{name: "BT", price_usd: 55000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: ["debe estar en mayúsculas y tener entre 3 y 4 letras"]} = errors_on(changeset)
    end

    test "no permite nombre con más de 4 letras" do
      attrs = %{name: "BITCOIN", price_usd: 55000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: ["debe estar en mayúsculas y tener entre 3 y 4 letras"]} = errors_on(changeset)
    end

    test "no permite precio negativo" do
      attrs = %{name: "BTC", price_usd: -100.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{price_usd: ["no puede ser negativo"]} = errors_on(changeset)
    end

    test "no permite nombres duplicados" do
      attrs = %{name: "BTC", price_usd: 55000.0}
      assert {:ok, _currency1} = Currencies.create_currency(attrs)
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert changeset.valid? == false
    end

    test "no permite nombre con números" do
      attrs = %{name: "BT1", price_usd: 1000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: [_]} = errors_on(changeset)
    end

    test "no permite nombre con caracteres especiales" do
      attrs = %{name: "BT$", price_usd: 1000.0}
      assert {:error, changeset} = Currencies.create_currency(attrs)
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  describe "get_currency/1" do
    test "obtiene una moneda existente por ID" do
      {:ok, created_currency} = Currencies.create_currency(%{
        name: "BTC",
        price_usd: 55000.0
      })

      currency = Currencies.get_currency(created_currency.id)
      assert currency.id == created_currency.id
      assert currency.name == "BTC"
    end

    test "retorna nil para ID inexistente" do
      assert Currencies.get_currency(99999) == nil
    end
  end

  describe "get_currency_by_name/1" do
    test "obtiene una moneda por nombre" do
      {:ok, _created_currency} = Currencies.create_currency(%{
        name: "ETH",
        price_usd: 3000.0
      })

      currency = Currencies.get_currency_by_name("ETH")
      assert currency.name == "ETH"
    end

    test "retorna nil para nombre inexistente" do
      assert Currencies.get_currency_by_name("NOEXISTE") == nil
    end
  end

  describe "list_currencies/0" do
    test "lista todas las monedas" do
      # Inicialmente vacío
      assert Currencies.list_currencies() == []

      # Crear algunas monedas
      {:ok, _currency1} = Currencies.create_currency(%{name: "BTC", price_usd: 55000.0})
      {:ok, _currency2} = Currencies.create_currency(%{name: "ETH", price_usd: 3000.0})

      currencies = Currencies.list_currencies()
      assert length(currencies) == 2
    end
  end

  describe "update_currency/2" do
    test "actualiza el precio correctamente" do
      {:ok, currency} = Currencies.create_currency(%{
        name: "BTC",
        price_usd: 55000.0
      })

      assert {:ok, updated_currency} = Currencies.update_currency(currency, %{price_usd: 56000.0})
      assert updated_currency.price_usd == 56000.0
      assert updated_currency.id == currency.id
      assert updated_currency.name == currency.name
    end

    test "no permite precio negativo" do
      {:ok, currency} = Currencies.create_currency(%{
        name: "BTC",
        price_usd: 55000.0
      })

      assert {:error, changeset} = Currencies.update_currency(currency, %{price_usd: -100.0})
      assert %{price_usd: ["no puede ser negativo"]} = errors_on(changeset)
    end

    test "permite actualizar a precio 0" do
      {:ok, currency} = Currencies.create_currency(%{
        name: "FREE",
        price_usd: 100.0
      })

      assert {:ok, updated_currency} = Currencies.update_currency(currency, %{price_usd: 0.0})
      assert updated_currency.price_usd == 0.0
    end

    test "no permite cambiar el nombre (nombre ignorado en update)" do
      {:ok, currency} = Currencies.create_currency(%{
        name: "BTC",
        price_usd: 55000.0
      })

      # Intentar cambiar el nombre no debe tener efecto
      assert {:ok, updated_currency} = Currencies.update_currency(currency, %{name: "ETH", price_usd: 56000.0})
      assert updated_currency.name == "BTC"  # El nombre no cambió
      assert updated_currency.price_usd == 56000.0  # Pero el precio sí
    end
  end

  describe "delete_currency/1" do
    test "elimina una moneda sin transacciones" do
      {:ok, currency} = Currencies.create_currency(%{
        name: "TEST",
        price_usd: 1.0
      })

      assert {:ok, deleted_currency} = Currencies.delete_currency(currency)
      assert deleted_currency.id == currency.id
      assert Currencies.get_currency(currency.id) == nil
    end

    # Este test pasará cuando se implemente la tabla de transacciones
    # test "no permite eliminar moneda con transacciones" do
    #   {:ok, currency} = Currencies.create_currency(%{
    #     name: "BTC",
    #     price_usd: 55000.0
    #   })
    #   # Crear una transacción asociada...
    #   assert {:error, :has_transactions} = Currencies.delete_currency(currency)
    # end
  end

  describe "currency_name_available?/1" do
    test "retorna true para nombre disponible" do
      assert Currencies.currency_name_available?("NEW") == true
    end

    test "retorna false para nombre en uso" do
      {:ok, _currency} = Currencies.create_currency(%{
        name: "BTC",
        price_usd: 55000.0
      })

      assert Currencies.currency_name_available?("BTC") == false
    end
  end

  describe "valid_currency_name?/1" do
    test "retorna true para nombre válido de 3 letras en mayúsculas" do
      assert Currencies.valid_currency_name?("BTC") == true
    end

    test "retorna true para nombre válido de 4 letras en mayúsculas" do
      assert Currencies.valid_currency_name?("USDT") == true
    end

    test "retorna false para nombre en minúsculas" do
      assert Currencies.valid_currency_name?("btc") == false
    end

    test "retorna false para nombre con menos de 3 letras" do
      assert Currencies.valid_currency_name?("BT") == false
    end

    test "retorna false para nombre con más de 4 letras" do
      assert Currencies.valid_currency_name?("BITCOIN") == false
    end

    test "retorna false para nombre con números" do
      assert Currencies.valid_currency_name?("BT1") == false
    end

    test "retorna false para nombre con caracteres especiales" do
      assert Currencies.valid_currency_name?("BT$") == false
    end

    test "retorna false para nombre vacío" do
      assert Currencies.valid_currency_name?("") == false
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
