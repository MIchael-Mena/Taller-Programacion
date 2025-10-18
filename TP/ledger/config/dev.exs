import Config

# Configuración de base de datos para desarrollo
config :ledger, Ledger.Repo,
  database: "ledger_dev", # Convencion: ledger_dev, ledger_test, ledger_prod
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
