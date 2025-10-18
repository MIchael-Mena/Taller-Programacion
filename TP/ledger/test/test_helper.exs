# Configurar el sandbox de Ecto para tests concurrentes
Ecto.Adapters.SQL.Sandbox.mode(Ledger.Repo, :manual)

ExUnit.start()
