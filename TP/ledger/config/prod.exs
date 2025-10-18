import Config

# Configuración de base de datos para producción
# En producción, se recomienda usar variables de entorno
config :ledger, Ledger.Repo,
  database: System.get_env("DATABASE_NAME") || "ledger_prod",
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  port: String.to_integer(System.get_env("DATABASE_PORT") || "5432"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
