# Anchor every path to THIS Makefile's directory, so `make postgres` works whether you run it
# from the repo, from the submodule path inside a host stack, or via `make -C <submodule>`.
ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
DC   := docker compose --env-file $(ROOT).env -f $(ROOT)compose.yml

.PHONY: postgres postgres-stop postgres-clear psql

# Bootstrap .env from the example on first run.
$(ROOT).env:
	@cp $(ROOT).env.example $(ROOT).env

# Start the shared stack (Postgres + Mailpit + Adminer).
postgres: $(ROOT).env
	@$(DC) up -d --wait
	@echo ""
	@echo "🐘 Postgres  localhost:$$(sed -n 's/^POSTGRES_PORT=//p' $(ROOT).env)"
	@echo "📬 Mailpit   http://localhost:$$(sed -n 's/^MAILPIT_UI_PORT=//p' $(ROOT).env)"
	@echo "🗄  AdminNeo  http://localhost:$$(sed -n 's/^ADMINNEO_PORT=//p' $(ROOT).env)/?username=postgres"

postgres-stop:
	@$(DC) down

# Destroy the shared data volume (all apps' databases). Destructive.
postgres-clear:
	@$(DC) down -v

# Interactive psql into the shared server (connects to the default `postgres` database).
psql:
	@docker exec -it postgres-dev-shared psql -U postgres
