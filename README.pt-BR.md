# Gerenciamento do Ambiente DSpace (Produção)

Este repositório centraliza a orquestração e o deploy automatizado da plataforma DSpace (Backend Spring Boot, Frontend Angular SSR, PostgeSQL e Apache Solr) utilizando Docker de forma modular.

---

## Pré-requisitos e Configuração Inicial

Antes de executar o script de deploy, é obrigatório configurar as variáveis de ambiente que serão utilizadas para clonagem dos repositórios, construção das imagens e credenciais da infraestrutura.

### Pré-requisitos

Antes de utilizar este projeto, certifique-se de que os seguintes requisitos foram atendidos.

#### Docker e Docker Compose

Instale o Docker Engine e o Docker Compose Plugin conforme a documentação oficial do Docker.

Verifique a instalação:

```bash
docker --version
docker compose version
```

#### Git

O Git é utilizado para clonar e atualizar automaticamente os repositórios do DSpace e do DSpace Angular.

Verifique a instalação:

```bash
git --version
```

#### Usuário com Permissão para Docker

O usuário responsável por executar o script `deploy.sh` deve possuir permissão para executar comandos Docker.

Verifique:

```bash
docker ps
```

Caso receba erro de permissão, adicione o usuário ao grupo `docker`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Ou faça logout/login novamente.

---

## Instalação Inicial ou Migração

⚠️ **Importante:** Os comandos `install` e `migrate` devem ser executados apenas uma única vez durante a criação inicial do ambiente.

Após a implantação inicial, utilize apenas os comandos de manutenção (`update`, `rebuild`, `restart` e `stop`).

### Opção 1 — Instalação Nova

Utilize esta opção quando desejar implantar um ambiente DSpace completamente novo, sem dados existentes.

```bash
./deploy.sh install
```

### Opção 2 — Migração de uma Instalação Existente

Utilize esta opção quando já existir uma instalação DSpace executando fora de containers (standalone) e desejar migrá-la para Docker.

```bash
./deploy.sh migrate
```

Durante a migração são transferidos:

- Banco de dados PostgreSQL
- Assetstore
- Índices Solr
- Arquivo `local.cfg`

### Requisitos da Migração

A migração foi projetada para converter uma instalação DSpace standalone existente em uma implantação Docker equivalente.

Para garantir compatibilidade, a instalação de origem e a instalação Docker devem utilizar:

- A mesma versão do DSpace
- O mesmo código-fonte
- As mesmas customizações e extensões
- Configurações compatíveis

#### Exemplos

✅ Compatível:

```text
DSpace 10.0 customizado → DSpace 10.0 customizado em Docker
```

✅ Compatível:

```text
DSpace 9.1 → DSpace 9.1 em Docker
```

❌ Não compatível:

```text
DSpace 8.x → DSpace 10.x
```

❌ Não compatível:

```text
DSpace 7.x → DSpace 9.x
```

Nesses casos, primeiro deve ser realizado o processo oficial de atualização do DSpace e somente depois a migração para Docker.

---

## Configuração Inicial

1. Copie os arquivos de exemplo para criar o seu arquivo `.env` e seu arquivo `local.cfg`:

   ```bash
   cp .env.example .env
   cp local.cfg.example local.cfg
   ```

2. Edite o arquivo `.env` com suas configurações específicas (repositórios, branches/tags, credenciais etc.).

3. Configure o arquivo `local.cfg` com as propriedades específicas do DSpace (e-mail, autenticação externa, integrações etc.).

4. ⚠️ Atenção Crítica: altere a variável `POSTGRES_PASSWORD` para uma senha forte antes de iniciar o ambiente pela primeira vez.

---

# Fluxo Recomendado

```text
                           Primeira Execução
                                   │
                  ┌────────────────┴────────────────┐
                  │                                 │
                  ▼                                 ▼
         ./deploy.sh install             ./deploy.sh migrate
                  │                                 │
                  └────────────────┬────────────────┘
                                   ▼
                         Ambiente em Produção
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
      update                    rebuild                   restart
        │                          │                          │
 Atualiza código          Reconstrói imagens       Reinicia containers
 e imagens                sem atualizar código
                                   │
                                   ▼
                                 stop
                                   │
                       Para temporariamente o ambiente
```

---

## Configuração do DSpace (`local.cfg`)

Além do arquivo `.env`, você pode configurar o arquivo `local.cfg`, que contém propriedades específicas da aplicação DSpace.

O arquivo `local.cfg` sobrescreve as configurações padrão do DSpace e permite personalizar funcionalidades que não estão disponíveis por meio das variáveis de ambiente.

### Exemplo de Configuração

```properties
# Configurações de e-mail
mail.server = smtp.gmail.com
mail.server.username = usuario@dominio.com
mail.server.password = senha-ou-app-password
mail.server.port = 587
```

### Observações

As propriedades listadas abaixo são gerenciadas pela implantação Docker e não devem ser modificadas no arquivo `local.cfg`.

#### Propriedades Fixas

- dspace.dir
- dspace.server.ssr.url
- db.url
- solr.server

Esses valores são necessários para a comunicação entre os containers na rede interna do Docker. Alterá-los pode impedir que o DSpace se conecte ao PostgreSQL, Solr ou outros serviços internos, causando falhas na inicialização ou funcionamento da aplicação.

#### Propriedades Gerenciadas pelo Docker Compose

- dspace.name (proveniente de `DSPACE_NAME`)
- dspace.server.url (proveniente de `DSPACE_SERVER_URL`)
- dspace.ui.url (proveniente de `DSPACE_UI_URL`)
- db.username (proveniente de `POSTGRES_USER`)
- db.password (proveniente de `POSTGRES_PASSWORD`)

Essas configurações devem ser alteradas no arquivo `.env`. Defini-las no `local.cfg` não produzirá efeito, pois os valores fornecidos pelo Docker Compose sobrescrevem os valores definidos neste arquivo.

#### Correspondência entre `local.cfg` e `.env`

- dspace.name ⇔ DSPACE_NAME
- dspace.server.url ⇔ DSPACE_SERVER_URL
- dspace.ui.url ⇔ DSPACE_UI_URL
- db.username ⇔ POSTGRES_USER
- db.password ⇔ POSTGRES_PASSWORD

> Alterações realizadas no arquivo `local.cfg` exigem a reinicialização do container backend para que sejam aplicadas.

---

## Script de Deploy Automatizado (`deploy.sh`)

O script `./deploy.sh` automatiza todo o ciclo de vida da aplicação.

### Como Utilizar

Certifique-se de que o script possui permissão de execução:

```bash
chmod +x deploy.sh
```

### Comandos Disponíveis

| Comando               | Descrição                                                             |
| --------------------- | --------------------------------------------------------------------- |
| `./deploy.sh install` | Realiza a instalação inicial de um novo ambiente DSpace.              |
| `./deploy.sh migrate` | Migra uma instalação DSpace standalone existente para Docker.         |
| `./deploy.sh update`  | Atualiza o código-fonte, reconstrói as imagens e reinicia o ambiente. |
| `./deploy.sh rebuild` | Reconstrói as imagens Docker sem atualizar o código-fonte.            |
| `./deploy.sh restart` | Reinicia os containers utilizando as imagens atuais.                  |
| `./deploy.sh stop`    | Para todos os containers do ambiente sem removê-los.                  |

---

## Gerenciamento Granular de Serviços (Docker Compose)

Em cenários de manutenção ou depuração, não é necessário derrubar todo o ecossistema. O Docker Compose permite gerenciar serviços individualmente.

### Serviços Disponíveis

- **dspacedb**: Banco de dados PostgreSQL.
- **dspacesolr**: Mecanismo de busca Apache Solr.
- **dspace**: Backend REST do DSpace.
- **dspace-angular**: Frontend Angular SSR.

### Reiniciar um Serviço

```bash
docker compose -f docker-compose.prod.yml restart dspace
```

### Iniciar um Serviço

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr
```

### Parar um Serviço

```bash
docker compose -f docker-compose.prod.yml stop dspace-angular
```

---

## Logs e Comandos Úteis

### Monitoramento de Logs do Docker (Saída padrão)

Para visualizar e acompanhar em tempo real os logs de saída de um container específico: `docker logs -f <nome-do-serviço>`

Exemplo:
```bash
docker logs -f dspace-angular
```

### Visualizar Logs Internos do DSpace

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log
```

### Verificar Configuração Ativa do Frontend

```bash
docker exec -it dspace-angular cat /app/src/assets/config.json
```

### Criar Usuário Administrador

```bash
docker exec -it dspace /dspace/bin/dspace create-administrator
```
