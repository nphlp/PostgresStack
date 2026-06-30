# PostgresStack

Infrastructure de **développement local partagée** pour tous les stacks (Cubiing, GreenSense, …).
Un seul serveur Postgres (**une base de données par application**), un seul Mailpit, un seul AdminNeo.

Ce dépôt remplace les `compose.postgres.yml` propres à chaque stack par une infra unique, consommée
comme **sous-module git**. Il généralise le principe déjà en place dans GreenSense pour les worktrees :
« le serveur PostgreSQL local est partagé ; on isole une base de données par consommateur. »

## Pourquoi

Auparavant, chaque stack utilisait le même nom de projet Compose (`name: postgres`) et codait en dur les
mêmes ports hôte (Prisma Studio `5555`, Mailpit `8025`/`1025`). Docker les réconciliait en un seul projet,
si bien que démarrer un stack évinçait l'autre. Un stack unique partagé supprime cette duplication.

## Services & ports

| Service   | Conteneur             | Hôte                    | Description                                            |
| --------- | --------------------- | ----------------------- | ------------------------------------------------------ |
| Postgres  | `postgres-dev-shared` | `5433`                  | Base `postgres` par défaut + une base par app (`cubiing-db`, `greensense-db`, …) |
| Mailpit   | `mailpit-dev-shared`  | `1025` SMTP / `8025` UI | Boîte mail de dev partagée                             |
| AdminNeo  | `adminneo-dev-shared` | `8081`                  | Navigateur DB (fork d'Adminer, thèmes light/dark, voit toutes les bases) |

- Volume : `postgres-dev-shared`
- Réseau : `dev-postgres-network` (bridge nommé)

**AdminNeo** (fork moderne d'Adminer) gère le **light/dark** nativement. `NEO_DEFAULT_DRIVER`/
`NEO_DEFAULT_SERVER` pré-remplissent le pilote + le serveur sur le formulaire, et `make postgres`
affiche l'URL avec `?username=postgres` — il ne reste qu'à taper le mot de passe. Prisma Studio est
**spécifique au schéma** d'une app, donc il reste côté stack hôte (Cubiing : `make prisma-studio`).

## Commandes

```bash
make postgres        # démarre Postgres + Mailpit + AdminNeo (crée .env depuis .env.example au 1er run)
make postgres-stop   # arrête la stack (conserve les données)
make postgres-clear  # détruit le volume partagé (toutes les bases de toutes les apps) — destructif
make psql            # psql interactif dans le serveur partagé
```

Le conteneur démarre toujours grâce à la base **`postgres`** créée par défaut par l'image (du nom de
l'utilisateur, puisque `POSTGRES_DB` n'est pas défini). C'est la base partagée par défaut, non utilisée
par les apps. **Chaque app crée sa propre base** via son propre setup (Cubiing : `db.sh setup` ; etc.) —
ce dépôt ne crée aucune base applicative.

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
   postgres-stop:
   	@$(MAKE) -C infra/postgres-stack postgres-stop
   postgres-clear:
   	@$(MAKE) -C infra/postgres-stack postgres-clear
   ```
   La base applicative est créée par le setup du stack hôte (`make app-setup` / migrations), pas ici.
3. Pointer le `DATABASE_URL` du stack vers la base partagée :
   ```
   DATABASE_URL=postgres://postgres:password@localhost:5433/<app>-db
   ```
4. Sur un clone neuf : `git submodule update --init --recursive`.

## Modèle d'identifiants

Superutilisateur de dev **partagé** (`postgres` + un mot de passe de dev unique, `password`), avec
**une base par app**. Identifiants de dev local uniquement — ne jamais les utiliser au-delà de localhost.
Si une isolation plus forte devient nécessaire, on bascule vers un rôle + une base dédiés par app.
