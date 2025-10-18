import Config

# Configuración de Ecto
config :ledger,
  ecto_repos: [Ledger.Repo]

# Importar configuraciones específicas del entorno
import_config "#{config_env()}.exs"
