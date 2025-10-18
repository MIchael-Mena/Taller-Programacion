.PHONY: dev db stop db-logs db-status setup-docker

dev:
	iex -S mix phx.server

db:
	sudo docker compose up -d

stop:
	sudo docker compose down

db-logs:
	sudo docker compose logs -f postgres

db-status:
	sudo docker compose ps

# Comando para agregar usuario al grupo docker (requiere logout/login después)
setup-docker:
	@echo "Agregando usuario al grupo docker..."
	sudo usermod -aG docker $$USER
	@echo "✓ Completado. Cierra sesión y vuelve a entrar para aplicar los cambios."
	@echo "Después de eso podrás usar docker sin sudo."

# Configurar bases de datos
db-create:
	mix ecto.create
	@MIX_ENV=test mix ecto.create

db-migrate:
	mix ecto.migrate
	@MIX_ENV=test mix ecto.migrate

db-reset:
	mix ecto.reset
	@MIX_ENV=test mix ecto.reset

# Setup completo: iniciar docker y crear bases de datos
setup: db db-create
	@echo "✓ Setup completado!"