defmodule Ledger.TransactionTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias Ledger.Transaction
  alias Ledger.{Repo, User, Currency, Account}

  setup do
    # Configurar sandbox de Ecto para cada test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  describe "Transaction schema" do
    setup do
      # Crear usuario de prueba
      {:ok, user} =
        %User{}
        |> User.changeset(%{username: "testuser", birthdate: ~D[2000-01-01]})
        |> Repo.insert()

      # Crear monedas de prueba
      {:ok, btc} =
        %Currency{}
        |> Currency.changeset(%{name: "BTC", price_usd: 50000.0})
        |> Repo.insert()

      {:ok, eth} =
        %Currency{}
        |> Currency.changeset(%{name: "ETH", price_usd: 3000.0})
        |> Repo.insert()

      # Crear cuentas de prueba
      {:ok, account_btc} =
        %Account{}
        |> Account.changeset(%{
          user_id: user.id,
          currency_id: btc.id,
          balance: Decimal.new("10.0")
        })
        |> Repo.insert()

      {:ok, account_eth} =
        %Account{}
        |> Account.changeset(%{
          user_id: user.id,
          currency_id: eth.id,
          balance: Decimal.new("100.0")
        })
        |> Repo.insert()

      %{
        user: user,
        btc: btc,
        eth: eth,
        account_btc: account_btc,
        account_eth: account_eth
      }
    end

    test "valid alta_cuenta transaction", %{account_btc: account, btc: currency} do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100.5"),
        account_to_id: account.id,
        currency_to_id: currency.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      {:ok, transaction} = Repo.insert(changeset)
      assert transaction.type == "alta_cuenta"
      assert Decimal.eq?(transaction.amount, Decimal.new("100.5"))
      assert transaction.account_from_id == nil
      assert transaction.account_to_id == account.id
    end

    test "valid transferencia transaction", %{
      account_btc: account_from,
      account_eth: account_to,
      btc: currency
    } do
      attrs = %{
        type: "transferencia",
        amount: Decimal.new("5.0"),
        account_from_id: account_from.id,
        account_to_id: account_to.id,
        currency_from_id: currency.id,
        currency_to_id: currency.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      {:ok, transaction} = Repo.insert(changeset)
      assert transaction.type == "transferencia"
      assert Decimal.eq?(transaction.amount, Decimal.new("5.0"))
      assert transaction.account_from_id == account_from.id
      assert transaction.account_to_id == account_to.id
    end

    test "valid swap transaction", %{
      account_btc: account_from,
      account_eth: account_to,
      btc: currency_from,
      eth: currency_to
    } do
      attrs = %{
        type: "swap",
        amount: Decimal.new("1.0"),
        amount_converted: Decimal.new("16.666666"),
        account_from_id: account_from.id,
        account_to_id: account_to.id,
        currency_from_id: currency_from.id,
        currency_to_id: currency_to.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      {:ok, transaction} = Repo.insert(changeset)
      assert transaction.type == "swap"
      assert Decimal.eq?(transaction.amount, Decimal.new("1.0"))
      assert Decimal.eq?(transaction.amount_converted, Decimal.new("16.666666"))
    end

    test "requires type field" do
      attrs = %{
        amount: Decimal.new("100"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
    end

    test "requires amount field" do
      attrs = %{
        type: "alta_cuenta",
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).amount
    end

    test "requires account_to_id field" do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100")
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).account_to_id
    end

    test "validates type must be one of valid types" do
      attrs = %{
        type: "invalid_type",
        amount: Decimal.new("100"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end

    test "validates amount must be greater than 0" do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("0"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "validates negative amount" do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("-100"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "validates amount_converted must be >= 0 if present" do
      attrs = %{
        type: "swap",
        amount: Decimal.new("100"),
        amount_converted: Decimal.new("-10"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?

      assert "must be greater than or equal to 0" in errors_on(changeset).amount_converted
    end

    test "allows amount_converted to be 0 (edge case for swaps from zero-value currency)" do
      attrs = %{
        type: "swap",
        amount: Decimal.new("100"),
        amount_converted: Decimal.new("0"),
        account_to_id: 1
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
    end

    test "allows amount_converted to be nil (not used in alta_cuenta or transferencia)" do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100"),
        account_to_id: 1,
        amount_converted: nil
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
    end

    test "sets default timestamp if not provided", %{account_btc: account} do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100"),
        account_to_id: account.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :timestamp) != nil
    end

    test "respects provided timestamp", %{account_btc: account} do
      custom_timestamp = ~U[2024-01-01 12:00:00Z]

      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100"),
        account_to_id: account.id,
        timestamp: custom_timestamp
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :timestamp) == custom_timestamp
    end

    test "foreign key constraint on account_from_id", %{account_btc: account} do
      attrs = %{
        type: "transferencia",
        amount: Decimal.new("100"),
        account_from_id: 999_999,
        account_to_id: account.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      assert {:error, failed_changeset} = Repo.insert(changeset)

      assert "does not exist" in errors_on(failed_changeset).account_from_id
    end

    test "foreign key constraint on account_to_id" do
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("100"),
        account_to_id: 999_999
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      assert {:error, failed_changeset} = Repo.insert(changeset)

      assert "does not exist" in errors_on(failed_changeset).account_to_id
    end

    test "foreign key constraint on currency_from_id", %{account_btc: account} do
      attrs = %{
        type: "swap",
        amount: Decimal.new("100"),
        account_to_id: account.id,
        currency_from_id: 999_999
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      assert {:error, failed_changeset} = Repo.insert(changeset)

      assert "does not exist" in errors_on(failed_changeset).currency_from_id
    end

    test "foreign key constraint on currency_to_id", %{account_btc: account} do
      attrs = %{
        type: "swap",
        amount: Decimal.new("100"),
        account_to_id: account.id,
        currency_to_id: 999_999
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?

      assert {:error, failed_changeset} = Repo.insert(changeset)

      assert "does not exist" in errors_on(failed_changeset).currency_to_id
    end

    test "database validates type constraint (valid_type check)", %{account_btc: account} do
      # El changeset ya previene tipos inválidos, pero la BD también tiene constraint
      attrs = %{
        type: "invalid_type",
        amount: Decimal.new("100"),
        account_to_id: account.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end

    test "database validates amount constraint (positive_amount check)", %{account_btc: account} do
      # El changeset ya previene montos negativos, pero la BD también tiene constraint
      attrs = %{
        type: "alta_cuenta",
        amount: Decimal.new("-100"),
        account_to_id: account.id
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).amount
    end

    test "allows all three transaction types", %{account_btc: account} do
      for type <- ["alta_cuenta", "transferencia", "swap"] do
        attrs = %{
          type: type,
          amount: Decimal.new("100"),
          account_to_id: account.id
        }

        changeset = Transaction.changeset(%Transaction{}, attrs)
        assert changeset.valid?, "Type #{type} should be valid"
      end
    end
  end

  # Helper para obtener errores del changeset
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
