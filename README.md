# DSpace Environment Management (Production)

This repository centralizes the orchestration and automated deployment of the DSpace platform (Spring Boot Backend, Angular SSR Frontend, PostgreSQL, and Apache Solr) using Docker in a modular architecture.


[Versão em Português](README.pt-BR.md)

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
sudo git clone https://github.com/projetos-codic-ibict/ibict-dspace-docker-deploy.git
sudo chown -R dspace:dspace /opt/ibict-dspace-docker-deploy

```

> ⚠️ **From this point forward, switch to the `dspace` user:** 

```bash
sudo su - dspace 

# and navigate to 
cd /opt/ibict-dspace-docker-deploy

```

### Environment Configuration Files

Create your local configuration files based on the repository templates:

```bash
cp .env.example .env
cp local.cfg.example local.cfg

```

1. **Edit the `.env` file:** Configure your environment variables (repositories, tags/branches, credentials, and ports).
2. **⚠️ Critical Attention:** Change the `POSTGRES_PASSWORD` variable in the `.env` file to a strong password before starting the environment for the first time.
3. **Edit the `local.cfg` file:** Add DSpace application-specific properties (metadata, SMTP/Email server, external authentication, etc.).

### Important Rules for `local.cfg`

To prevent networking conflicts within the internal Docker network, strictly adhere to the following restrictions:

| Property Type          | Forbidden Keys in `local.cfg`                                                     | Reason / Where to Change                                                                    |
| ---------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| **Fixed by Docker**    | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server`                    | **Do not modify**. These values are required for internal communication between containers. |
| **Managed via `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Define in `.env` only**. These values are dynamically injected via Compose.               |

> 💡 **Note:** Any future modifications made to the `local.cfg` file will require a restart of the backend container (`dspace`) to take effect.

---

## 3. Available Commands (`deploy.sh`)

The `./deploy.sh` script automates the infrastructure lifecycle. It includes a mechanism that detects `root` privileges on the first run to set up initial structures, then transparently delegates all subsequent processing to the `dspace` user.

Ensure the script has execution permissions:

```bash
chmod +x deploy.sh

```

### Primary Operations (Run once)

- **Fresh Installation from Scratch:**

```bash
./deploy.sh install

```

- **Migrating an Existing Installation (Standalone to Docker):**

```bash
./deploy.sh migrate

```

> ⚠️ **Migration Compatibility:** The source installation and the Docker container **must use the exact same DSpace version** (e.g., 9.x to 9.x). Do not use this migration script to perform version upgrades (e.g., 7.x to 9.x). Upgrade your standalone DSpace instance before migrating.

### Lifecycle and Maintenance Operations

| Command               | Description                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------- |
| `./deploy.sh update`  | Updates the source code (Git), rebuilds images without cache, and restarts the environment. |
| `./deploy.sh rebuild` | Rebuilds local Docker images keeping the current code intact, then restarts.                |
| `./deploy.sh restart` | Restarts all containers reusing the current images.                                         |
| `./deploy.sh start`   | Starts existing containers.                                                                 |
| `./deploy.sh stop`    | Stops the environment containers without removing volumes or data.                          |

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

# Verify the active configuration file generated for the frontend
docker exec -it dspace-angular cat /app/src/assets/config.json

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
