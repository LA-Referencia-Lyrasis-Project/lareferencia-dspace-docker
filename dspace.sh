#!/bin/bash

set -Eeuo pipefail

# File locks to prevent duplicate installations or migrations
LOCK_INSTALL=".lock_installed"
LOCK_MIGRATE=".lock_migrated"
LOCK_IN_PROGRESS=".lock_in_progress"
COMPOSE_FILE="docker-compose.prod.yml"
DOCKER_BUILD_DIR=".docker-build"
CURRENT_ACTION=""

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

load_env() {
    if [ ! -f .env ]; then
        echo "Error: .env file not found."
        exit 1
    fi

    local raw line key value

    while IFS= read -r raw || [ -n "$raw" ]; do
        line="${raw%$'\r'}"
        line="$(trim "$line")"

        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi

        if [[ "$line" == export[[:space:]]* ]]; then
            line="$(trim "${line#export}")"
        fi

        if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            echo "Error: invalid .env line: $raw"
            exit 1
        fi

        key="${BASH_REMATCH[1]}"
        value="$(trim "${BASH_REMATCH[2]}")"

        if [[ "${value:0:1}" == "\"" ]]; then
            if [ "${#value}" -lt 2 ] || [[ "${value: -1}" != "\"" ]]; then
                echo "Error: unterminated double-quoted value for $key in .env"
                exit 1
            fi
            value="${value:1:${#value}-2}"
            value="${value//\\\"/\"}"
        elif [[ "${value:0:1}" == "'" ]]; then
            if [ "${#value}" -lt 2 ] || [[ "${value: -1}" != "'" ]]; then
                echo "Error: unterminated single-quoted value for $key in .env"
                exit 1
            fi
            value="${value:1:${#value}-2}"
        else
            value="${value%%[[:space:]]#*}"
            value="$(trim "$value")"
        fi

        printf -v "$key" '%s' "$value"
        export "$key"
    done < .env
}

handle_failure() {
    local exit_code=$?

    if [ "$exit_code" -ne 0 ] && [ -n "${CURRENT_ACTION:-}" ] && [ -f "$LOCK_IN_PROGRESS" ]; then
        echo
        echo "Action failed: '$CURRENT_ACTION' did not finish successfully."
        echo "The in-progress lock '$LOCK_IN_PROGRESS' was kept to prevent accidental reuse of partial Docker volumes."
        echo "Inspect the failure and the Docker volumes before removing this lock manually."
    fi

    exit "$exit_code"
}

trap handle_failure EXIT

start_guarded_action() {
    CURRENT_ACTION="$1"

    if [ -f "$LOCK_IN_PROGRESS" ]; then
        echo "Action Blocked: An unfinished action was detected ($LOCK_IN_PROGRESS)."
        echo "Review the previous failure and Docker volumes before removing this lock manually."
        exit 1
    fi

    printf 'action=%s\nstarted_at=%s\n' "$CURRENT_ACTION" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$LOCK_IN_PROGRESS"
}

finish_guarded_action() {
    rm -f "$LOCK_IN_PROGRESS"
    CURRENT_ACTION=""
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

ensure_docker_volumes() {
    echo "Ensuring required Docker volumes exist..."
    docker volume create dspace_docker_deploy_assetstore >/dev/null || true
    docker volume create dspace_docker_deploy_solr_data >/dev/null || true
    docker volume create dspace-docker-deploy_pgdata >/dev/null || true
}

assert_docker_volume_empty() {
    local volume_name="$1"
    local description="$2"

    if ! docker run --rm -v "$volume_name":/data alpine sh -c '[ -z "$(find /data -mindepth 1 -maxdepth 1 -print -quit)" ]'; then
        echo "Error: Docker volume '$volume_name' for $description is not empty."
        echo "Refusing to continue because install/migrate requires clean data volumes."
        exit 1
    fi
}

assert_fresh_data_volumes() {
    assert_docker_volume_empty "dspace-docker-deploy_pgdata" "PostgreSQL data"
    assert_docker_volume_empty "dspace_docker_deploy_assetstore" "DSpace assetstore"
    assert_docker_volume_empty "dspace_docker_deploy_solr_data" "Solr data"
}

migrate_legacy_data() {
    echo "======= Validating Migration Requirements ======="
    local migrate_solr="${MIGRATE_SOLR_DATA:-false}"

    if [ ! -f "${OLD_DB_DUMP_PATH:-}" ]; then
        echo "Error: Legacy database dump file not found at ${OLD_DB_DUMP_PATH:-<empty>}"
        exit 1
    fi

    if [ ! -f "${OLD_LOCAL_CFG_PATH:-}" ]; then
        echo "Error: Legacy local.cfg file not found at ${OLD_LOCAL_CFG_PATH:-<empty>}"
        exit 1
    fi

    if [ ! -d "${OLD_ASSETSTORE_PATH:-}" ]; then
        echo "Error: Legacy assetstore directory not found at ${OLD_ASSETSTORE_PATH:-<empty>}"
        exit 1
    fi

    if [ "$migrate_solr" = "true" ]; then
        if [ ! -d "${OLD_SOLR_DATA_PATH:-}" ]; then
            echo "Error: Legacy Solr data directory not found at ${OLD_SOLR_DATA_PATH:-<empty>}"
            exit 1
        fi
    elif [ "$migrate_solr" != "false" ]; then
        echo "Error: MIGRATE_SOLR_DATA must be either true or false."
        exit 1
    fi

    ensure_docker_volumes
    assert_fresh_data_volumes

    echo "All source files and directories validated successfully."
    echo "======= Starting Legacy Migration to Docker ======="

    echo "Preparing database dump for import..."
    mkdir -p ./migration/db
    cp "$OLD_DB_DUMP_PATH" ./migration/db/01_init_migration.sql

    echo "Overwriting local.cfg with legacy configuration..."
    cp "$OLD_LOCAL_CFG_PATH" ./local.cfg

    echo "Migrating assetstore files via temporary container..."
    docker run --rm \
      -v "$OLD_ASSETSTORE_PATH":/from \
      -v dspace_docker_deploy_assetstore:/to \
      alpine sh -c "cp -r /from/. /to/"

    if [ "$migrate_solr" = "true" ]; then
        echo "Migrating Solr cores data via temporary container..."
        docker run --rm \
          -v "$OLD_SOLR_DATA_PATH":/from \
          -v dspace_docker_deploy_solr_data:/to \
          alpine sh -c "cp -r /from/. /to/ && chown -R 8983:8983 /to"
    else
        echo "Skipping legacy Solr data migration. Reindex DSpace after startup."
    fi

    echo "======= Legacy Migration Data Prepared Successfully ======="
}

require_env() {
    local missing=0
    local name

    for name in "$@"; do
        if [ -z "${!name:-}" ]; then
            echo "Error: required environment variable '$name' is empty or not defined."
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        exit 1
    fi
}

clone_repositories() {
    echo "======= Cloning Repositories ======="
    local backend_target="${DSPACE_BACKEND_TAG:-main}"
    local frontend_target="${DSPACE_FRONTEND_TAG:-main}"
    require_env DSPACE_BACKEND_REPO DSPACE_FRONTEND_REPO

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

ensure_clean_git_repo() {
    local repo_dir="$1"
    local repo_label="$2"

    if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
        echo "Error: $repo_label has local modifications in '$repo_dir'."
        echo "Commit, stash, or remove those changes before running update."
        git -C "$repo_dir" status --short
        exit 1
    fi
}

checkout_git_target() {
    local repo_dir="$1"
    local repo_label="$2"
    local target="$3"

    ensure_clean_git_repo "$repo_dir" "$repo_label"

    git -C "$repo_dir" fetch --all --tags --prune

    if git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/$target"; then
        echo "Checking out branch '$target' for $repo_label."
        git -C "$repo_dir" checkout "$target" 2>/dev/null || git -C "$repo_dir" checkout -B "$target" "origin/$target"
        git -C "$repo_dir" pull --ff-only origin "$target"
    elif git -C "$repo_dir" show-ref --verify --quiet "refs/tags/$target"; then
        echo "Checking out tag '$target' for $repo_label."
        git -C "$repo_dir" checkout --detach "$target"
    else
        echo "Error: target '$target' was not found as a remote branch or tag for $repo_label."
        exit 1
    fi
}

update_repositories() {
    echo "======= Updating Repositories (Git Fetch & Checkout) ======="
    local backend_target="${DSPACE_BACKEND_TAG:-main}"
    local frontend_target="${DSPACE_FRONTEND_TAG:-main}"

    if [ -d "DSpace" ]; then
        checkout_git_target "DSpace" "Backend" "$backend_target"
    else
        echo "Error: DSpace directory not found."
        exit 1
    fi

    if [ -d "dspace-angular" ]; then
        checkout_git_target "dspace-angular" "Frontend" "$frontend_target"
    else
        echo "Error: dspace-angular directory not found."
        exit 1
    fi
}

patch_dockerfiles() {
    echo "======= Generating Dockerfile Production Overrides ======="

    mkdir -p "$DOCKER_BUILD_DIR"

    if [ ! -f DSpace/Dockerfile ]; then
        echo "Error: DSpace/Dockerfile not found."
        exit 1
    fi

    if grep -q "^USER root$" DSpace/Dockerfile; then
        cp DSpace/Dockerfile "$DOCKER_BUILD_DIR/DSpace.Dockerfile"
    else
        sed '/RUN mkdir \/install/i USER root' DSpace/Dockerfile > "$DOCKER_BUILD_DIR/DSpace.Dockerfile"
    fi

    if [ ! -f dspace-angular/Dockerfile ]; then
        echo "Error: dspace-angular/Dockerfile not found."
        exit 1
    fi

    sed \
        -e '/ENV NODE_ENV=development/d' \
        -e '/CMD npm run serve -- --host 0.0.0.0/d' \
        -e '/ENTRYPOINT \[ "npm", "run", "serve" \]/d' \
        -e '/CMD \["--", "--host 0.0.0.0", "--poll 5000"\]/d' \
        -e '/# --- Native SSR Production Configuration (dspace-docker-deploy) ---/,$d' \
        dspace-angular/Dockerfile > "$DOCKER_BUILD_DIR/dspace-angular.Dockerfile"

    cat <<'EOF' >> "$DOCKER_BUILD_DIR/dspace-angular.Dockerfile"

# --- Native SSR Production Configuration (dspace-docker-deploy) ---
ENV NODE_ENV=production

# Força o limite de memória explicitamente para o processo de build do Angular
RUN NODE_OPTIONS="--max_old_space_size=4096" npm run build:prod

CMD ["npm", "run", "serve:ssr"]
EOF
    echo "Dockerfile overrides generated in $DOCKER_BUILD_DIR."
}

build_environment() {
    echo "======= Building Production Environment ======="
    export MAVEN_OPTS="-Dhttp.keepAlive=false -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.pool=false"
    docker compose -f "$COMPOSE_FILE" build --no-cache
}

start_containers() {
    echo "======= Starting Containers ======="
    docker compose -f "$COMPOSE_FILE" up -d
    echo "======= DSpace Production Environment Online ======="
}

remove_containers() {
    echo "======= Removing Existing Containers ======="
    docker compose -f "$COMPOSE_FILE" down --remove-orphans
}

restart_containers() {
    echo "======= Restarting Containers ======="
    docker compose -f "$COMPOSE_FILE" restart
}

clean_migration_files() {
    echo "======= Cleaning Temporary Migration Files ======="
    if [ -d "./migration" ]; then
        docker run --rm -v "$(pwd)":/workspace alpine sh -c "rm -rf /workspace/migration"
    else
        echo "No temporary migration directory found."
    fi
}

stop_containers() {
    echo "======= Stopping Containers ======="
    docker compose -f "$COMPOSE_FILE" stop
}

show_help() {
    local exit_code="${1:-1}"
    echo "Usage: $0 {install|migrate|update|rebuild|restart|start|stop|clean-migration|help}"
    echo
    echo "Commands:"
    echo "  install   Clone repositories and install a clean environment (Runs once)"
    echo "  migrate   Migrate legacy data into docker environment (Runs once)"
    echo "  update    Update source code, rebuild images, and restart"
    echo "  rebuild   Rebuild local images without updating source code and restart"
    echo "  restart   Restart the current containers"
    echo "  start     Start the current containers"
    echo "  stop      Stop all running containers"
    echo "  clean-migration  Remove temporary migration files after a successful migration"
    echo "  help      Show this help message"
    exit "$exit_code"
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION FLOW
# -----------------------------------------------------------------------------

if [ "${1:-}" = "" ]; then
    show_help 1
fi

load_env

case "$1" in
    install)
        check_locks
        start_guarded_action "install"
        clone_repositories
        patch_dockerfiles
        ensure_docker_volumes
        assert_fresh_data_volumes
        build_environment
        start_containers
        touch "$LOCK_INSTALL"
        finish_guarded_action
        echo "Success: System installed. Lock file $LOCK_INSTALL created."
        ;;
    migrate)
        check_locks
        start_guarded_action "migrate"
        clone_repositories
        patch_dockerfiles
        migrate_legacy_data
        build_environment
        start_containers
        touch "$LOCK_MIGRATE"
        finish_guarded_action
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
        restart_containers
        ;;
    start)
        start_containers
        ;;
    stop)
        stop_containers
        ;;
    clean-migration)
        clean_migration_files
        ;;
    help|-h|--help)
        show_help 0
        ;;
    *)
        show_help 1
        ;;
esac
