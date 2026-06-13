#!/bin/bash

set -e

# File locks to prevent duplicate installations or migrations
LOCK_INSTALL=".lock_installed"
LOCK_MIGRATE=".lock_migrated"

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

load_env() {
    if [ ! -f .env ]; then
        echo "Error: .env file not found."
        exit 1
    fi

    set -o allexport
    source .env
    set +o allexport
}

check_locks() {
    if [ -f "$LOCK_INSTALL" ]; then
        echo "Action Blocked: A previous installation was detected ($LOCK_INSTALL)."
        echo "You cannot run 'install' or 'migrate' again. Use 'update', 'rebuild', or 'restart'."
        exit 1
    fi

    if [ -f "$LOCK_MIGRATE" ]; then
        echo "Action Blocked: A previous migration was detected ($LOCK_MIGRATE)."
        echo "You cannot run 'install' or 'migrate' again. Use 'update', 'rebuild', or 'restart'."
        exit 1
    fi
}

migrate_legacy_data() {
    echo "======= Validating Migration Requirements ======="

    # 1. Validação antecipada (Fail-Fast)
    if [ ! -f "$OLD_DB_DUMP_PATH" ]; then
        echo "Error: Legacy database dump file not found at $OLD_DB_DUMP_PATH"
        exit 1
    fi

    if [ ! -f "$OLD_LOCAL_CFG_PATH" ]; then
        echo "Error: Legacy local.cfg file not found at $OLD_LOCAL_CFG_PATH"
        exit 1
    fi

    if [ ! -d "$OLD_ASSETSTORE_PATH" ]; then
        echo "Error: Legacy assetstore directory not found at $OLD_ASSETSTORE_PATH"
        exit 1
    fi

    if [ ! -d "$OLD_SOLR_DATA_PATH" ]; then
        echo "Error: Legacy Solr data directory not found at $OLD_SOLR_DATA_PATH"
        exit 1
    fi

    echo "All source files and directories validated successfully."
    echo "======= Starting Legacy Migration to Docker ======="

    # 2. Banco de Dados (Prepara o dump para o container do Postgres)
    echo "Preparing database dump for import..."
    mkdir -p ./migration/db
    cp "$OLD_DB_DUMP_PATH" ./migration/db/01_init_migration.sql

    # 3. Configurações (Sobrescreve o local.cfg do projeto)
    echo "Overwriting local.cfg with legacy configuration..."
    cp "$OLD_LOCAL_CFG_PATH" ./local.cfg

    # 4. Inicializa volumes vazios do Docker
    echo "Creating Docker volumes if they don't exist..."
    docker volume create dspace_docker_deploy_assetstore >/dev/null || true
    docker volume create dspace_docker_deploy_solr_data >/dev/null || true

    # 5. Copia os Arquivos Físicos (Assetstore) usando Container Intermediário
    echo "Migrating assetstore files via temporary container..."
    docker run --rm \
      -v "$OLD_ASSETSTORE_PATH":/from \
      -v dspace_docker_deploy_assetstore:/to \
      alpine sh -c "cp -r /from/. /to/"

    # 6. Copia os Cores do Solr e ajusta as permissões nativamente
    echo "Migrating Solr cores data via temporary container..."
    docker run --rm \
      -v "$OLD_SOLR_DATA_PATH":/from \
      -v dspace_docker_deploy_solr_data:/to \
      alpine sh -c "cp -r /from/. /to/ && chown -R 8983:8983 /to"

    echo "======= Legacy Migration Data Prepared Successfully ======="
}

clone_repositories() {
    echo "======= Cloning Repositories ======="
    local backend_target="${DSPACE_BACKEND_TAG:-main}"
    local frontend_target="${DSPACE_FRONTEND_TAG:-main}"

    if [ ! -d "DSpace" ]; then
        echo "Cloning backend from: $DSPACE_BACKEND_REPO (Target: $backend_target)"
        git clone -b "$backend_target" "$DSPACE_BACKEND_REPO" DSpace
    else
        echo "DSpace directory already exists. Skipping clone."
    fi

    if [ ! -d "dspace-angular" ]; then
        echo "Cloning frontend from: $DSPACE_FRONTEND_REPO (Target: $frontend_target)"
        git clone -b "$frontend_target" "$DSPACE_FRONTEND_REPO" dspace-angular
    else
        echo "dspace-angular directory already exists. Skipping clone."
    fi
}

update_repositories() {
    echo "======= Updating Repositories (Git Fetch & Checkout) ======="
    local backend_target="${DSPACE_BACKEND_TAG:-main}"
    local frontend_target="${DSPACE_FRONTEND_TAG:-main}"

    if [ -d "DSpace" ]; then
        cd DSpace
        git fetch --all --tags --prune
        git checkout "$backend_target"
        git pull origin "$backend_target" 2>/dev/null || echo "Notice: Backend is using a fixed tag."
        cd ..
    else
        echo "Error: DSpace directory not found."
        exit 1
    fi

    if [ -d "dspace-angular" ]; then
        cd dspace-angular
        git fetch --all --tags --prune
        git checkout "$frontend_target"
        git pull origin "$frontend_target" 2>/dev/null || echo "Notice: Frontend is using a fixed tag."
        cd ..
    else
        echo "Error: dspace-angular directory not found."
        exit 1
    fi
}

patch_dockerfiles() {
    echo "======= Applying Dockerfile Production Patches ======="

    # -------------------------------------------------------------------------
    # Backend (DSpace)
    # -------------------------------------------------------------------------

    if [ -f DSpace/Dockerfile ] && ! grep -q "^USER root$" DSpace/Dockerfile; then
        sed -i '/RUN mkdir \/install/i USER root' DSpace/Dockerfile
        echo "Backend production Dockerfile patched."
    fi

    if [ -f DSpace/Dockerfile.test ] && ! grep -q "^USER root$" DSpace/Dockerfile.test; then
        sed -i '/RUN mkdir \/install/i USER root' DSpace/Dockerfile.test
        echo "Backend development Dockerfile patched."
    fi

    # -------------------------------------------------------------------------
    # Frontend (Angular SSR)
    # -------------------------------------------------------------------------
    
    if [ -f dspace-angular/Dockerfile ]; then
        # Remove configurações antigas de dev
        sed -i '/ENV NODE_ENV=development/d' dspace-angular/Dockerfile
        sed -i '/CMD npm run serve -- --host 0.0.0.0/d' dspace-angular/Dockerfile
        sed -i '/ENTRYPOINT \[ "npm", "run", "serve" \]/d' dspace-angular/Dockerfile
        sed -i '/CMD \["--", "--host 0.0.0.0", "--poll 5000"\]/d' dspace-angular/Dockerfile

        # Remove bloco anterior para garantir idempotência
        sed -i '/# --- Native SSR Production Configuration (dspace-docker-deploy) ---/,$d' dspace-angular/Dockerfile

        # Injeta o bloco de produção clássico
        cat <<'EOF' >> dspace-angular/Dockerfile

# --- Native SSR Production Configuration (dspace-docker-deploy) ---
ENV NODE_ENV=production

# Força o limite de memória explicitamente para o processo de build do Angular
RUN NODE_OPTIONS="--max_old_space_size=4096" npm run build:prod

CMD ["npm", "run", "serve:ssr"]
EOF
        echo "Frontend Dockerfile optimized for SSR production (DSpace 9/10 compatible)."
    fi
}

build_environment() {
    echo "======= Building Production Environment ======="
    export MAVEN_OPTS="-Dhttp.keepAlive=false -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.pool=false"
    docker compose -f docker-compose.prod.yml build --no-cache
}

start_containers() {
    echo "======= Starting Containers ======="
    docker compose -f docker-compose.prod.yml up -d
    echo "======= DSpace Production Environment Online ======="
}

remove_containers() {
    echo "======= Removing Existing Containers ======="
    docker compose -f docker-compose.prod.yml down --remove-orphans
    
    # Apaga a pasta de migração por completo usando um container temporário
    if [ -d "./migration" ]; then
        echo "Cleaning up temporary migration directory..."
        docker run --rm -v "$(pwd)":/workspace alpine sh -c "rm -rf /workspace/migration"
    fi
}

stop_containers() {
    echo "======= Stopping Containers ======="
    docker compose -f docker-compose.prod.yml stop
}

show_help() {
    echo "Usage: $0 {install|migrate|update|rebuild|restart|stop}"
    echo
    echo "Commands:"
    echo "  install   Clone repositories and install a clean environment (Runs once)"
    echo "  migrate   Migrate legacy data into docker environment (Runs once)"
    echo "  update    Update source code, rebuild images, and restart"
    echo "  rebuild   Rebuild local images without updating source code and restart"
    echo "  restart   Restart the current containers"
    echo "  stop      Stop all running containers"
    exit 1
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION FLOW
# -----------------------------------------------------------------------------

load_env

case "$1" in
    install)
        check_locks
        clone_repositories
        patch_dockerfiles
        remove_containers
        build_environment
        start_containers
        touch "$LOCK_INSTALL"
        echo "Success: System installed. Lock file $LOCK_INSTALL created."
        ;;
    migrate)
        check_locks
        clone_repositories
        patch_dockerfiles
        remove_containers
        migrate_legacy_data
        build_environment
        start_containers
        touch "$LOCK_MIGRATE"
        echo "Success: Migration finished. Lock file $LOCK_MIGRATE created."
        ;;
    update)
        update_repositories
        patch_dockerfiles
        remove_containers
        build_environment
        start_containers
        ;;
    rebuild)
        patch_dockerfiles
        remove_containers
        build_environment
        start_containers
        ;;
    restart)
        remove_containers
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    *)
        show_help
        ;;
esac