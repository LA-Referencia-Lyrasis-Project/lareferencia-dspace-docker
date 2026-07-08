# DSpace Environment Management (Production)

This repository centralizes the orchestration and automated deployment of the DSpace platform (Spring Boot Backend, Angular SSR Frontend, PostgreSQL, and Apache Solr) using Docker in a modular architecture.

[Versão em Português](README.pt-BR.md)

[Versión en Español](README.es.md)

---

## 1. Prerequisites

Before starting, ensure that your infrastructure meets the minimum software and system permission requirements.

### Required Tools

- **Docker Engine** and **Docker Compose Plugin** installed.
- **Git** installed.

Verify the installed versions using the following commands:

```bash
docker --version
docker compose version
git --version

```

### System User Configuration

For security purposes in a production environment, create a dedicated system user named `dspace` and add it to the Docker group:

```bash
# Create the 'dspace' system user with a home directory
sudo useradd -m -s /bin/bash dspace

# Set a password for the user
sudo passwd dspace

# Add the user to the docker group
sudo usermod -aG docker dspace
newgrp docker

```

---

## 2. Clone and Initial Configuration

### Downloading the Project

Navigate to the `/opt` directory, clone the repository, and adjust the ownership permissions for the newly created user:

```bash
cd /opt
sudo git clone https://github.com/LA-Referencia-Lyrasis-Project/lareferencia-dspace-docker-deploy.git
sudo chown -R dspace:dspace /opt/lareferencia-dspace-docker-deploy

```

> ⚠️ **From this point forward, switch to the `dspace` user:**

```bash
sudo su - dspace

# and navigate to
cd /opt/lareferencia-dspace-docker-deploy

```

### Environment Configuration Files

Create your local configuration files based on the repository templates:

```bash
cp .env.example .env
cp local.cfg.example local.cfg

```

1. **Edit the `.env` file:** Configure your environment variables (repositories, tags/branches, credentials, ports, Docker subnet, and migration options).
2. **⚠️ Critical Attention:** Change the `POSTGRES_PASSWORD` variable in the `.env` file to a strong password before starting the environment for the first time.
3. **Edit the `local.cfg` file:** Add DSpace application-specific properties (metadata, SMTP/Email server, external authentication, etc.).

The deployment script reads `.env` as data and does not execute it as a shell script. Use standard `KEY=value` lines and quote values that contain spaces.

### Important Rules for `local.cfg`

To prevent networking conflicts within the internal Docker network, strictly adhere to the following restrictions:

| Property Type          | Forbidden Keys in `local.cfg`                                                     | Reason / Where to Change                                                                    |
| ---------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| **Fixed by Docker**    | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server`                    | **Do not modify**. These values are required for internal communication between containers. |
| **Managed via `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Define in `.env` only**. These values are dynamically injected via Compose.               |

> 💡 **Note:** Any future modifications made to the `local.cfg` file will require a restart of the backend container (`dspace`) to take effect.

---

## 3. Available Commands (`dspace.sh`)

The `./dspace.sh` script automates the infrastructure lifecycle. Run it as the dedicated `dspace` user after that user has Docker permissions.

Ensure the script has execution permissions:

```bash
chmod +x dspace.sh

```

### Primary Operations (Run once)

- **Fresh Installation from Scratch:**

```bash
./dspace.sh install

```

- **Migrating an Existing Installation (Standalone to Docker):**

```bash
./dspace.sh migrate

```

#### Migrating

> ⚠️ **Migration Compatibility:** The source installation and the Docker container **must use the exact same DSpace version** (e.g., 9.x to 9.x). Do not use this migration script to perform version upgrades (e.g., 7.x to 9.x). Upgrade your standalone DSpace instance before migrating.

Migration requires empty Docker volumes for PostgreSQL, assetstore, and Solr. If a previous attempt failed, inspect the volumes before removing `.lock_in_progress` and retrying.

By default, legacy Solr data is not copied (`MIGRATE_SOLR_DATA=false`). This is the recommended path for most migrations; start the environment and run a DSpace reindex after migration. Set `MIGRATE_SOLR_DATA=true` only when you intentionally need to copy old Solr cores.

When `MIGRATE_SOLR_DATA=false`, preserve only the required Solr data through a logical export instead of copying the physical core directories. Before running the migration, execute this on the current DSpace installation:

```bash
mkdir -p /tmp/dspace-solr-export
[dspace]/bin/dspace solr-export-statistics -i authority -d /tmp/dspace-solr-export -f
[dspace]/bin/dspace solr-export-statistics -i statistics -d /tmp/dspace-solr-export -f
```

After migration, with the Docker environment running and the new Solr volume empty, reindex Discovery and import the exported data:

```bash
docker exec -it dspace /dspace/bin/dspace index-discovery -b
docker cp /tmp/dspace-solr-export dspace:/tmp/dspace-solr-export
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i authority -d /tmp/dspace-solr-export -c
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i statistics -d /tmp/dspace-solr-export -c
```

Use `-c` only when the target core can be cleared before import. If the old installation has statistics shards, such as `statistics-2024`, export and import each shard with `-i`.

### Lifecycle and Maintenance Operations

| Command                       | Description                                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./dspace.sh install`         | Performs a fresh installation from scratch by cloning/updating configured repositories, building images, and starting the full environment.                         |
| `./dspace.sh migrate`         | Migrates an existing standalone installation to Docker using the configured migration paths and options.                                                            |
| `./dspace.sh update`          | Updates source code with Git, rebuilds images without cache, and recreates the environment. The command stops if local changes exist in cloned DSpace repositories. |
| `./dspace.sh rebuild`         | Rebuilds local Docker images keeping the current code intact, then recreates the environment.                                                                       |
| `./dspace.sh restart`         | Restarts existing containers without removing or recreating them.                                                                                                   |
| `./dspace.sh start`           | Starts existing containers.                                                                                                                                         |
| `./dspace.sh stop`            | Stops the environment containers without removing volumes or data.                                                                                                  |
| `./dspace.sh health`          | Checks whether Solr, PostgreSQL, backend server, and frontend UI are healthy and reachable.                                                                        |
| `./dspace.sh clean-migration` | Removes temporary migration files after a successful migration.                                                                                                     |
| `./dspace.sh help`            | Displays the list of available commands and usage guidance.                                                                                                         |

The script generates Dockerfile overrides in `.docker-build/` instead of editing the cloned upstream repositories in place.

---

## 4. Useful Commands and Granular Operations

For debugging or maintenance scenarios, you can manage specific services (`dspacedb`, `dspacesolr`, `dspace`, `dspace-angular`) in isolation using native Docker Compose.

### Managing Individual Services

```bash
# Restart only the DSpace backend
docker compose -f docker-compose.prod.yml restart dspace

# Start only the Solr engine
docker compose -f docker-compose.prod.yml up -d dspacesolr

# Stop the Frontend Angular SSR service
docker compose -f docker-compose.prod.yml stop dspace-angular

```

### DSpace Utilities

```bash
# Create the initial administrator account (DSpace CLI)
docker exec -it dspace /dspace/bin/dspace create-administrator

# Solr Reindexing (Discovery)
docker exec -it dspace /dspace/bin/dspace index-discovery -b

# Optional after migration: remove temporary migration files
./dspace.sh clean-migration

# Check overall service health (DB, Solr, Server, UI)
./dspace.sh health

# Verify the frontend runtime configuration
docker exec -it dspace-angular cat /app/dist/browser/assets/config.json
docker exec -it dspace-angular cat /app/config/config.yml
docker exec -it dspace-angular env | grep '^DSPACE_' | sort

```

---

## 5. Monitoring Logs

### Docker Standard Output Logs (Stdout)

To follow container outputs in real-time:

```bash
docker logs -f <service-name>

# Example for the frontend:
docker logs -f dspace-angular

```

### DSpace Internal Application Logs

To trace database persistence errors, DSpace Core routines, or debug the REST API:

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log

```

---

## 6. Contributing

Contributions are welcome.

If you find a bug or want to request a feature, please open an issue and include as much context as possible.

If you want to contribute code, submit a Pull Request with a clear description of your changes.
