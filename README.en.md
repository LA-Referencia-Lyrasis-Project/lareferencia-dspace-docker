# DSpace Environment Management (Production)

This repository centralizes the orchestration and automated deployment of the DSpace platform (Spring Boot Backend, Angular SSR Frontend, PostgreSQL and Apache Solr) using Docker in a modular way.

---

## Prerequisites and Initial Configuration

Before running the deployment script, you must configure the environment variables that will be used for repository cloning, image building, and infrastructure credentials.

### Prerequisites

Before using this project, ensure that the following requirements are met.

#### Docker and Docker Compose

Install Docker Engine and the Docker Compose Plugin according to the official Docker documentation.

Verify the installation:

```bash
docker --version
docker compose version
```

#### Git

Git is used to automatically clone and update the DSpace and DSpace Angular repositories.

Verify the installation:

```bash
git --version
```

#### User with Docker Permissions

The user responsible for running the `deploy.sh` script must have permission to execute Docker commands.

Verify:

```bash
docker ps
```

If you receive a permission error, add the user to the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Or log out and log back in.

---

## Initial Installation or Migration

⚠️ **Important:** The `install` and `migrate` commands should only be executed once during the initial environment setup.

After the initial deployment, only use the maintenance commands (`update`, `rebuild`, `restart`, and `stop`).

### Option 1 — New Installation

Use this option when deploying a completely new DSpace environment without any existing data.

```bash
./deploy.sh install
```

### Option 2 — Migration from an Existing Installation

Use this option when you already have a standalone DSpace installation running outside Docker and want to migrate it to Docker.

```bash
./deploy.sh migrate
```

During migration, the following data is transferred:

* PostgreSQL database
* Assetstore
* Solr indexes
* `local.cfg` file

### Migration Requirements

The migration process is designed to convert an existing standalone DSpace installation into an equivalent Docker deployment.

To ensure compatibility, the source installation and the Docker installation must use:

* The same DSpace version
* The same source code
* The same customizations and extensions
* Compatible configurations

#### Examples

✅ Compatible:

```text
Customized DSpace 10.0 → Customized DSpace 10.0 in Docker
```

✅ Compatible:

```text
DSpace 9.1 → DSpace 9.1 in Docker
```

❌ Not Compatible:

```text
DSpace 8.x → DSpace 10.x
```

❌ Not Compatible:

```text
DSpace 7.x → DSpace 9.x
```

In these scenarios, you must first perform the official DSpace upgrade process and only then migrate to Docker.

---

## Initial Configuration

1. Copy the example file to create your `.env` file:

   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file with your specific settings (repositories, branches/tags, credentials, etc.).

3. Configure the `local.cfg` file with DSpace-specific properties (email, external authentication, integrations, etc.).

4. ⚠️ Critical Warning: Change the `POSTGRES_PASSWORD` variable to a strong password before starting the environment for the first time.

---

# Recommended Workflow

```text
                            First Execution
                                   │
                  ┌────────────────┴────────────────┐
                  │                                 │
                  ▼                                 ▼
         ./deploy.sh install             ./deploy.sh migrate
                  │                                 │
                  └────────────────┬────────────────┘
                                   ▼
                        Production Environment
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
      update                    rebuild                   restart
        │                          │                          │
 Updates source code       Rebuilds images         Restarts containers
 and Docker images         without updating code
                                   │
                                   ▼
                                 stop
                                   │
                    Temporarily stops the environment
```

---

## DSpace Configuration (`local.cfg`)

In addition to the `.env` file, you may configure the `local.cfg` file, which contains DSpace application-specific properties.

The `local.cfg` file overrides the default DSpace configuration and allows customization of features that are not exposed through environment variables.

### Configuration Example

```properties
# Email settings
mail.server = smtp.gmail.com
mail.server.username = user@example.com
mail.server.password = password-or-app-password
mail.server.port = 587
```

### Notes

The properties listed below are managed by the Docker deployment and should not be modified in the `local.cfg` file.

#### Fixed Properties

* dspace.dir
* dspace.server.ssr.url
* db.url
* solr.server

These values are required for communication between containers on the internal Docker network. Changing them may prevent DSpace from connecting to PostgreSQL, Solr, or other internal services, causing startup or runtime failures.

#### Properties Managed by Docker Compose

* dspace.name (from `DSPACE_NAME`)
* dspace.server.url (from `DSPACE_SERVER_URL`)
* dspace.ui.url (from `DSPACE_UI_URL`)
* db.username (from `POSTGRES_USER`)
* db.password (from `POSTGRES_PASSWORD`)

These settings must be modified in the `.env` file. Defining them in `local.cfg` will have no effect because the values provided by Docker Compose override any values defined in this file.

#### Mapping Between `local.cfg` and `.env`

* dspace.name ⇔ DSPACE_NAME
* dspace.server.url ⇔ DSPACE_SERVER_URL
* dspace.ui.url ⇔ DSPACE_UI_URL
* db.username ⇔ POSTGRES_USER
* db.password ⇔ POSTGRES_PASSWORD

> Changes made to `local.cfg` require restarting the backend container before they take effect.

---

## Automated Deployment Script (`deploy.sh`)

The `./deploy.sh` script automates the entire application lifecycle.

### Usage

Ensure the script has execution permissions:

```bash
chmod +x deploy.sh
```

### Available Commands

| Command               | Description                                                         |
| --------------------- | ------------------------------------------------------------------- |
| `./deploy.sh install` | Performs the initial installation of a new DSpace environment.      |
| `./deploy.sh migrate` | Migrates an existing standalone DSpace installation to Docker.      |
| `./deploy.sh update`  | Updates source code, rebuilds images, and restarts the environment. |
| `./deploy.sh rebuild` | Rebuilds Docker images without updating source code.                |
| `./deploy.sh restart` | Restarts containers using the current images.                       |
| `./deploy.sh stop`    | Stops all environment containers without removing them.             |

---

## Granular Service Management (Docker Compose)

For maintenance and troubleshooting scenarios, you do not need to stop the entire ecosystem. Docker Compose allows individual service management.

### Available Services

* **dspacedb**: PostgreSQL database.
* **dspacesolr**: Apache Solr search engine.
* **dspace**: DSpace REST backend.
* **dspace-angular**: Angular SSR frontend.

### Restart a Service

```bash
docker compose -f docker-compose.prod.yml restart dspace
```

### Start a Service

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr
```

### Stop a Service

```bash
docker compose -f docker-compose.prod.yml stop dspace-angular
```

---

## Logs and Useful Commands

### View Docker Logs

```bash
docker logs -f dspace-angular
```

### View Internal DSpace Logs

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log
```

### Check Active Frontend Configuration

```bash
docker exec -it dspace-angular cat /app/src/assets/config.json
```

### Create an Administrator User

```bash
docker exec -it dspace /dspace/bin/dspace create-administrator
```
