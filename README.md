# PostgresStack

Infrastructure de **développement local partagée** pour tous les stacks (Cubiing, GreenSense, …).
Un seul serveur Postgres (**une base de données par application**), un seul Mailpit, un seul Adminer.

Ce dépôt remplace les `compose.postgres.yml` propres à chaque stack par une infra unique, consommée
comme **sous-module git**. Il généralise le principe déjà en place dans GreenSense pour les worktrees :
« le serveur PostgreSQL local est partagé ; on isole une base de données par consommateur. »

## Pourquoi

Auparavant, chaque stack utilisait le même nom de projet Compose (`name: postgres`) et codait en dur les
mêmes ports hôte (Prisma Studio `5555`, Mailpit `8025`/`1025`). Docker les réconciliait en un seul projet,
si bien que démarrer un stack évinçait l'autre. Un stack unique partagé supprime cette duplication.

## Services & ports

| Service   | Conteneur             | Hôte    | Description                                   |
| --------- | --------------------- | ------- | --------------------------------------------- |
| Postgres  | `postgres-dev-shared` | `5435`  | Une base par app (`cubiing-db`, `greensense-db`, `greensense_wt_NN`, …) |
| Mailpit   | `mailpit-dev-shared`  | `1025` SMTP / `8025` UI | Boîte mail de dev partagée           |
| Adminer   | `adminer-dev-shared`  | `8081`  | Navigateur DB universel (voit toutes les bases) |

- Volume partagé : `postgres-dev-shared`
- Réseau : `dev-postgres-network` (bridge nommé)

Adminer est le navigateur par défaut (léger, voit chaque base du serveur). Pour une UI plus riche,
remplace le service `adminer` par `dpage/pgadmin4` ou `dbeaver/cloudbeaver`. Prisma Studio reste
disponible par app à la demande (`bunx prisma studio`).

## Commandes

```bash
make postgres        # démarre Postgres + Mailpit + Adminer (crée .env depuis .env.example au 1er run)
make postgres-stop   # arrête la stack (conserve les données)
make postgres-clear  # détruit le volume partagé (toutes les bases de toutes les apps) — destructif
make psql            # psql interactif dans le serveur partagé
make logs            # logs en suivi
make ensure-db DB=greensense-db   # crée une base si elle n'existe pas (idempotent)
```

Le `Makefile` est **indépendant de l'emplacement** : il s'ancre à son propre dossier, donc `make postgres`
fonctionne depuis le dépôt, depuis le chemin du sous-module dans un stack hôte, ou via `make -C <sous-module>`.

## Comment un stack hôte le consomme

1. Ajouter le sous-module :
   ```bash
   git submodule add <PostgresStack-url> infra/postgres-stack
   ```
2. Déléguer les cibles Make du stack hôte vers le sous-module :
   ```makefile
   postgres:
   	@$(MAKE) -C infra/postgres-stack postgres
   	@$(MAKE) -C infra/postgres-stack ensure-db DB=<app>-db
   postgres-stop:
   	@$(MAKE) -C infra/postgres-stack postgres-stop
   postgres-clear:
   	@$(MAKE) -C infra/postgres-stack postgres-clear
   ```
3. Pointer le `DATABASE_URL` du stack vers la base partagée :
   ```
   DATABASE_URL=postgres://postgres:dev-password@localhost:5435/<app>-db
   ```
4. Sur un clone neuf : `git submodule update --init --recursive`.

## Modèle d'identifiants

Superutilisateur de dev **partagé** (`postgres` + un mot de passe de dev unique, `dev-password`), avec
**une base par app**. Identifiants de dev local uniquement — ne jamais les utiliser au-delà de localhost.
Si une isolation plus forte devient nécessaire, on bascule vers un rôle + une base dédiés par app via
`scripts/ensure-db.sh`.
