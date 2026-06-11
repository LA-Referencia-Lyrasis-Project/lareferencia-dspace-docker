#!/bin/bash

set -e

# --- FUNÇÕES MODULARES ---

carregar_env() {
    if [ ! -f .env ]; then
        echo "Erro: Arquivo .env não encontrado."
        exit 1
    fi

    set -o allexport
    source .env
    set +o allexport
}

clonar_repositorios() {
    echo "======= Clonando os Repositórios ======="
    local alvo_backend="${DSPACE_BACKEND_TAG:-main}"
    local alvo_frontend="${DSPACE_FRONTEND_TAG:-main}"

    if [ ! -d "DSpace" ]; then
        echo "Clonando backend de: $DSPACE_BACKEND_REPO (Alvo: $alvo_backend)"
        git clone -b "$alvo_backend" "$DSPACE_BACKEND_REPO" DSpace
    else
        echo "Pasta DSpace já existe. Pulando clone."
    fi

    if [ ! -d "dspace-angular" ]; then
        echo "Clonando frontend de: $DSPACE_FRONTEND_REPO (Alvo: $alvo_frontend)"
        git clone -b "$alvo_frontend" "$DSPACE_FRONTEND_REPO" dspace-angular
    else
        echo "Pasta dspace-angular já existe. Pulando clone."
    fi
}

atualizar_repositorios() {
    echo "======= Atualizando os Repositórios (Git Fetch & Checkout) ======="
    local alvo_backend="${DSPACE_BACKEND_TAG:-main}"
    local alvo_frontend="${DSPACE_FRONTEND_TAG:-main}"
    
    # Atualização do Backend
    if [ -d "DSpace" ]; then
        echo "Atualizando backend para o alvo: $alvo_backend..."
        cd DSpace
        git fetch --all --tags --prune
        git checkout "$alvo_backend"
        git pull origin "$alvo_backend" 2>/dev/null || echo "Nota: Backend está em uma Tag fixa."
        cd ..
    else
        echo "Erro: Pasta DSpace não encontrada para atualização."
        exit 1
    fi

    # Atualização do Frontend
    if [ -d "dspace-angular" ]; then
        echo "Atualizando frontend para o alvo: $alvo_frontend..."
        cd dspace-angular
        git fetch --all --tags --prune
        git checkout "$alvo_frontend"
        git pull origin "$alvo_frontend" 2>/dev/null || echo "Nota: Frontend está em uma Tag fixa."
        cd ..
    else
        echo "Erro: Pasta dspace-angular não encontrada para atualização."
        exit 1
    fi
}

corrigir_dockerfiles() {
    echo "======= Corrigindo permissões e modos de produção nos Dockerfiles ======="

    # -------------------------------------------------------------------------
    # Backend (DSpace)
    # -------------------------------------------------------------------------

    if [ -f DSpace/Dockerfile ] && ! grep -q "^USER root$" DSpace/Dockerfile; then
        sed -i '/RUN mkdir \/install/i USER root' DSpace/Dockerfile
        echo "Dockerfile de produção do backend corrigido."
    fi

    if [ -f DSpace/Dockerfile.test ] && ! grep -q "^USER root$" DSpace/Dockerfile.test; then
        sed -i '/RUN mkdir \/install/i USER root' DSpace/Dockerfile.test
        echo "Dockerfile.test de desenvolvimento do backend corrigido."
    fi

    # -------------------------------------------------------------------------
    # Frontend (Angular SSR)
    # -------------------------------------------------------------------------

    if [ -f dspace-angular/Dockerfile ]; then

        # Remove bloco de desenvolvimento padrão
        sed -i '/ENV NODE_ENV=development/d' dspace-angular/Dockerfile
        sed -i '/CMD npm run serve -- --host 0.0.0.0/d' dspace-angular/Dockerfile
        
        # Remove bloco injetado anteriormente
        sed -i '/# --- Configuração de Produção SSR Nativa (dspace-docker-deploy) ---/,$d' \
            dspace-angular/Dockerfile

        # Adiciona novamente o bloco de produção
        cat <<'EOF' >> dspace-angular/Dockerfile

# --- Configuração de Produção SSR Nativa (dspace-docker-deploy) ---
ENV NODE_ENV=production

# Executa a compilação durante o build da imagem
RUN npm run build:prod

# Inicializa o servidor SSR no runtime
CMD ["npm", "run", "serve:ssr"]

EOF

        echo "Dockerfile do frontend otimizado para produção SSR."
    fi
}

executar_build() {
    echo "======= Reconstruindo o Ambiente de PRODUÇÃO ======="
    # Injeta tolerância a falhas de rede para evitar 'Connection reset' no Maven
    export MAVEN_OPTS="-Dhttp.keepAlive=false -Dmaven.wagon.http.retryHandler.count=5 -Dmaven.wagon.http.pool=false"
    docker compose -f docker-compose.prod.yml build --no-cache
}

subir_containers() {
    echo "======= Subindo os Containers ======="
    docker compose -f docker-compose.prod.yml up -d
    echo "======= Ambiente DSpace de PRODUÇÃO online! ======="
}

derrubar_containers() {
    echo "======= Derrubando Containers Atuais ======="
    docker compose -f docker-compose.prod.yml down --remove-orphans
}

parar_containers() {
    echo "======= Parando Containers ======="
    docker compose -f docker-compose.prod.yml stop
}

exibir_ajuda() {
    echo "Uso: $0 {install|update|rebuild|restart}"
    echo "  install : Faz o clone inicial e instala todo o ambiente"
    echo "  update  : Atualiza o código fonte (git pull), reconstrói as imagens e reinicia"
    echo "  rebuild : Reconstrói as imagens locais sem atualizar o código e reinicia"
    echo "  restart : Apenas reinicia os containers atuais"
    exit 1
}

# --- FLUXO PRINCIPAL DE EXECUÇÃO ---

carregar_env

case "$1" in
    install)
        clonar_repositorios
        corrigir_dockerfiles
        derrubar_containers
        executar_build
        subir_containers
        ;;
    update)
        atualizar_repositorios
        corrigir_dockerfiles
        derrubar_containers
        executar_build
        subir_containers
        ;;
    rebuild)
        corrigir_dockerfiles
        derrubar_containers
        executar_build
        subir_containers
        ;;
    restart)
        derrubar_containers
        subir_containers
        ;;
    stop)
        parar_containers
        ;;
    *)
        exibir_ajuda
        ;;
esac