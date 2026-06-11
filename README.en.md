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

3. ⚠️ Critical Warning: Change the `POSTGRES_PASSWORD` variable to a strong password of your choice before starting the environment for the first time.

## Automated Deployment Script (`deploy.sh`)

The `./deploy.sh` script automates the entire application lifecycle. It manages Git updates, fixes critical infrastructure permissions, and injects network fault tolerance parameters (`MAVEN_OPTS`) to mitigate connection issues (`Connection reset`) during backend builds.

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
