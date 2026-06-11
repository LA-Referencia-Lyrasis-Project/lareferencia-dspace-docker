# Gerenciamento do Ambiente DSpace (Produção)

Este repositório centraliza a orquestração e o deploy automatizado da plataforma DSpace (Backend Spring Boot, Frontend Angular SSR e Apache Solr) utilizando Docker de forma modular.

---

## Pré-requisitos e Configuração Inicial

Antes de rodar o script de deploy, é obrigatório configurar as variáveis de ambiente que guiarão o clone, o build e as credenciais da infraestrutura.

1. Copie o arquivo de exemplo para criar o seu `.env`:
   ```bash
   cp .env.example .env
   ```
   
2. Edite o `.env` com as suas configurações específicas (repositórios, tags/branches, credenciais, etc.).
3. ⚠️ Atenção Crítica: Altere a variável POSTGRES_PASSWORD para uma senha forte de sua preferência antes de iniciar o ambiente pela primeira vez.

## Script de Deploy Automatizado (`deploy.sh`)

O script `./deploy.sh` automatiza todo o ciclo de vida da aplicação. Ele gerencia as atualizações via Git, corrige permissões críticas de infraestrutura e injeta parâmetros de tolerância a falhas de rede (`MAVEN_OPTS`) para mitigar quedas de conexão (`Connection reset`) durante o build do backend.

### Como usar

Certifique-se de que o script possui permissão de execução:
```bash
chmod +x deploy.sh
```

Execute o comando passando uma das opções abaixo:


|**Comando**|**Descrição**|
|---|---|
|`./deploy.sh install`|Realiza o clone inicial dos repositórios (back/front), aplica patches de permissão, constrói as imagens e sobe os containers.|
|`./deploy.sh update`|Entra em cada subpasta, executa o `git pull` para trazer o código mais recente, reconstrói as imagens do zero (`--no-cache`) e reinicia o ambiente.|
|`./deploy.sh rebuild`|Força a reconstrução de todas as imagens Docker locais do zero (sem atualizar o código via Git) e reinicia os containers.|
|`./deploy.sh restart`|Remove e recria rapidamente todos os containers atuais, sem alterar as imagens ou o código. Útil para aplicar mudanças no `.env`.|


## 🛠️ Gerenciamento Granular de Serviços (Docker Compose)

Em cenários de manutenção ou depuração, você não precisa derrubar todo o ecossistema. O Docker Compose permite parar, iniciar ou reiniciar serviços de forma isolada.

### Lista de Serviços Disponíveis

* **`dspacedb`** : Banco de dados PostgreSQL onde os metadados e esquemas estão armazenados.
* **`dspacesolr`** : Mecanismo de busca Apache Solr (contendo os cores de busca, estatísticas e autoridade).
* **`dspace`** : Backend da aplicação (API REST em Spring Boot embarcado).
* **`dspace-angular`** : Frontend da aplicação rodando em modo Server-Side Rendering (Node.js).

---

### Parar e Remover um Serviço Específico

Para desligar e remover o container de apenas um serviço, liberando a porta sem afetar os outros componentes que estão rodando:

```bash
docker compose -f docker-compose.prod.yml down <nome-do-serviço>

```

**Exemplo prático (Frontend):**

```bash
docker compose -f docker-compose.prod.yml down dspace-angular

```

---

### Criar e Iniciar um Serviço Específico

Para ler novas configurações de volumes, arquivo `.env` ou aplicar uma nova imagem e subir o container isolado novamente em background:

```bash
docker compose -f docker-compose.prod.yml up -d <nome-do-serviço>

```

**Exemplo prático (Solr):**

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr

```

---

### Reiniciar um Serviço Rapidamente

Se você alterou apenas uma configuração simples e quer dar um *reboot* rápido no container sem removê-lo por completo da rede:

```bash
docker compose -f docker-compose.prod.yml restart <nome-do-serviço>

```

**Exemplo prático (Backend):**

```bash
docker compose -f docker-compose.prod.yml restart dspace

```