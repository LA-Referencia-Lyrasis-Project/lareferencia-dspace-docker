# DSpace Environment Management (Production)

This repository centralizes the orchestration and automated deployment of the DSpace platform (Spring Boot Backend, Angular SSR Frontend, and Apache Solr) using Docker in a modular way.

---

## Prerequisites and Initial Configuration

Before running the deployment script, you must configure the environment variables that will control repository cloning, image building, and infrastructure credentials.

1. Copy the example file to create your `.env` file:

   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file with your specific configuration (repositories, tags/branches, credentials, etc.).
3. Configure the `local.cfg` file with DSpace-specific properties (email, external authentication, etc.).
4. ⚠️ **Critical Warning:** Change the `POSTGRES_PASSWORD` variable to a strong password of your choice before starting the environment for the first time.

## DSpace Configuration (`local.cfg`)

In addition to the `.env` file, you can configure the `local.cfg` file, which contains DSpace-specific application properties.

The `local.cfg` file overrides DSpace default settings and allows customization of features that are not exposed through environment variables.

### Configuration Example

```properties
# Email settings
mail.server = smtp.gmail.com
mail.server.username = user@example.com
mail.server.password = app-password
mail.server.port = 587
```

### Notes

The properties listed below are managed by the Docker deployment and should not be modified in the `local.cfg` file.

Fixed properties:

* `dspace.dir`
* `dspace.server.ssr.url`
* `db.url`
* `solr.server`

These values are required for communication between containers on the internal Docker network. Changing them may prevent DSpace from connecting to PostgreSQL, Solr, or other internal services, causing startup or runtime failures.

The following properties are also managed by Docker Compose:

* `dspace.name` (provided by `DSPACE_NAME`)
* `dspace.server.url` (provided by `DSPACE_SERVER_URL`)
* `dspace.ui.url` (provided by `DSPACE_UI_URL`)
* `db.username` (provided by `POSTGRES_USER`)
* `db.password` (provided by `POSTGRES_PASSWORD`)

These settings must be changed in the `.env` file. Defining them in `local.cfg` will have no effect because the values provided by Docker Compose override the values defined in this file.

Mapping between `local.cfg` properties and `.env` variables:

* `dspace.name` ⇔ `DSPACE_NAME`
* `dspace.server.url` ⇔ `DSPACE_SERVER_URL`
* `dspace.ui.url` ⇔ `DSPACE_UI_URL`
* `db.username` ⇔ `POSTGRES_USER`
* `db.password` ⇔ `POSTGRES_PASSWORD`

* Changes to the `local.cfg` file require restarting the backend container before they take effect.


## Automated Deployment Script (`deploy.sh`)

The `./deploy.sh` script automates the entire application lifecycle.

### Usage

Make sure the script has execution permission:

```bash
chmod +x deploy.sh
```

Run one of the following commands (use `sudo` if your user is not part of the `docker` group):

| Command               | Description                                                                                                                                                    |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./deploy.sh install` | Performs the initial repository clone (backend/frontend), applies permission patches, builds images, and starts the containers.                                |
| `./deploy.sh update`  | Enters each repository directory, executes `git pull` to fetch the latest code, rebuilds all images from scratch (`--no-cache`), and restarts the environment. |
| `./deploy.sh rebuild` | Forces a complete rebuild of all local Docker images without updating the source code and restarts the containers.                                             |
| `./deploy.sh restart` | Quickly removes and recreates all containers without modifying images or source code. Useful for applying changes to the `.env` file.                          |

## 🛠️ Granular Service Management (Docker Compose)

During maintenance or troubleshooting, you do not need to stop the entire ecosystem. Docker Compose allows you to stop, start, or restart services individually.

> Permission Note: If required, prepend `sudo` to the `docker` and `docker compose` commands shown below.

### Available Services

* **`dspacedb`**: PostgreSQL database containing metadata and schemas.
* **`dspacesolr`**: Apache Solr search engine (search, statistics, and authority cores).
* **`dspace`**: Application backend (embedded Spring Boot REST API).
* **`dspace-angular`**: Frontend application running in Server-Side Rendering (SSR) mode with Node.js.

### Stop and Remove a Specific Service

```bash
docker compose -f docker-compose.prod.yml down <service-name>
```

Example:

```bash
docker compose -f docker-compose.prod.yml down dspace-angular
```

### Create and Start a Specific Service

```bash
docker compose -f docker-compose.prod.yml up -d <service-name>
```

Example:

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr
```

### Restart a Specific Service

```bash
docker compose -f docker-compose.prod.yml restart <service-name>
```

Example:

```bash
docker compose -f docker-compose.prod.yml restart dspace
```

## Logs and Useful Commands

> Permission Note: If required, prepend `sudo` to the `docker` and `docker compose` commands shown below.

### Docker Log Monitoring

```bash
docker logs -f <service-name>

# Frontend example
docker logs -f dspace-angular
```

### DSpace Internal Log Monitoring

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log
```

### Verify Active Frontend Configuration

```bash
docker exec -it dspace-angular cat /app/src/assets/config.json
```

### Create an Administrator User (E-Person)

```bash
docker exec -it dspace /dspace/bin/dspace create-administrator
```
