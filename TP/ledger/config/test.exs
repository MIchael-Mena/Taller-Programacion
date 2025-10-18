import Config

# Configuración de base de datos para tests
config :ledger, Ledger.Repo,
  database: "ledger_test#{System.get_env("MIX_TEST_PARTITION")}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configurar el logger para tests
config :logger, level: :warning
