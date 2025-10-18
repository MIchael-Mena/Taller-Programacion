defmodule Ledger.Application do
  @moduledoc """
  El módulo Application para Ledger.

  Este módulo inicia el árbol de supervisión de la aplicación,
  incluyendo el Repo de Ecto para la conexión a PostgreSQL.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Inicia el Repo de Ecto
      Ledger.Repo
    ]

    opts = [strategy: :one_for_one, name: Ledger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
