# Gerenciamento do Ambiente DSpace (Produção)

Este repositório centraliza a orquestração e o deploy automatizado da plataforma DSpace (Backend Spring Boot, Frontend Angular SSR, PostgreSQL e Apache Solr) utilizando Docker de forma modular.

---

## 1. Pré-requisitos

Antes de iniciar, garanta que a infraestrutura atenda aos requisitos mínimos de software e permissões de sistema.

### Ferramentas Necessárias

- **Docker Engine** e **Docker Compose Plugin** instalados.
- **Git** instalado.

Verifique as versões com os comandos:

```bash
docker --version
docker compose version
git --version

```

### Configuração do Usuário do Sistema

Para segurança em ambiente de produção, crie um usuário dedicado chamado `dspace` e adicione-o ao grupo do Docker:

```bash
# Cria o usuário de sistema 'dspace' com diretório home
sudo useradd -m -s /bin/bash dspace

# Define uma senha para o usuário
sudo passwd dspace

# Adiciona o usuário ao grupo docker
sudo usermod -aG docker dspace
newgrp docker

```

---

## 2. Clone e Configuração Inicial

### Download do Projeto

Navegue até o diretório `/opt`, clone o repositório e ajuste as permissões para o usuário criado:

```bash
cd /opt
sudo git clone https://github.com/LA-Referencia-Lyrasis-Project/lareferencia-dspace-docker-deploy.git
sudo chown -R dspace:dspace /opt/lareferencia-dspace-docker-deploy

```

> ⚠️ **A partir deste ponto, mude para o usuário `dspace`:**

```bash
sudo su - dspace

### e acesse
cd /opt/lareferencia-dspace-docker-deploy

```

### Arquivos de Configuração Ambiente

Crie os arquivos locais com base nos templates do repositório:

```bash
cp .env.example .env
cp local.cfg.example local.cfg

```

1. **Editar o arquivo `.env`:** Configure as variáveis de ambiente (repositórios, tags/branches, credenciais, portas, subnet Docker e opções de migração).
2. **⚠️ Atenção Crítica:** Altere a variável `POSTGRES_PASSWORD` no `.env` para uma senha forte antes de iniciar o ambiente.
3. **Editar o arquivo `local.cfg`:** Adicione as propriedades da aplicação DSpace (metadados, SMTP/E-mail, autenticação externa, etc.).

O script de deploy lê o `.env` como dados e não executa o arquivo como script shell. Use linhas no formato `KEY=value` e coloque valores com espaços entre aspas.

### Regras Importantes para o `local.cfg`

Para evitar conflitos na rede interna do Docker, siga as restrições abaixo:

| Tipo de Propriedade        | Chaves Proibidas no `local.cfg`                                                   | Motivo / Onde Alterar                                                                |
| -------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **Fixas pelo Docker**      | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server`                    | **Não alterar**. Valores necessários para a comunicação interna entre os containers. |
| **Gerenciadas via `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Definir apenas no `.env**`. Valores injetados dinamicamente via Compose.           |

> 💡 **Nota:** Qualquer alteração futura realizada no arquivo `local.cfg` exige a reinicialização do container backend (`dspace`) para entrar em vigor.

---

## 3. Comandos Disponíveis (`dspace.sh`)

O script `./dspace.sh` gerencia o ciclo de vida da infraestrutura. Execute-o como o usuário dedicado `dspace` depois que esse usuário tiver permissão para usar o Docker.

Garanta a permissão de execução:

```bash
chmod +x dspace.sh

```

### Operações Principais (Executadas apenas uma vez)

- **Instalação Nova do Zero:**

```bash
./dspace.sh install

```

- **Migração de Instalação Existente (Standalone para Docker):**

```bash
./dspace.sh migrate

```

#### Migração

> ⚠️ **Compatibilidade da Migração:** A instalação de origem e o container Docker **devem usar a mesma versão do DSpace** (ex: 9.x para 9.x). Não use o script de migração para atualizar versões (ex: 7.x para 9.x). Atualize o DSpace standalone antes de migrar.

A migração exige volumes Docker vazios para PostgreSQL, assetstore e Solr. Se uma tentativa anterior falhar, inspecione os volumes antes de remover `.lock_in_progress` e tentar novamente.

Por padrão, os dados legados do Solr não são copiados (`MIGRATE_SOLR_DATA=false`). Esse é o caminho recomendado para a maioria das migrações; inicie o ambiente e execute a reindexação do DSpace depois da migração. Use `MIGRATE_SOLR_DATA=true` apenas quando for realmente necessário copiar cores antigos do Solr.

Quando `MIGRATE_SOLR_DATA=false`, preserve apenas os dados necessários do Solr por exportação lógica, não copiando os diretórios físicos dos cores. Antes de executar a migração, rode no DSpace atual:

```bash
mkdir -p /tmp/dspace-solr-export
[dspace]/bin/dspace solr-export-statistics -i authority -d /tmp/dspace-solr-export -f
[dspace]/bin/dspace solr-export-statistics -i statistics -d /tmp/dspace-solr-export -f
```

Depois da migração, com o ambiente Docker iniciado e o Solr novo vazio, reindexe o Discovery e importe os dados exportados:

```bash
docker exec -it dspace /dspace/bin/dspace index-discovery -b
docker cp /tmp/dspace-solr-export dspace:/tmp/dspace-solr-export
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i authority -d /tmp/dspace-solr-export -c
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i statistics -d /tmp/dspace-solr-export -c
```

Use `-c` somente quando o core de destino puder ser limpo antes da importação. Se a instalação antiga tiver shards de estatísticas, como `statistics-2024`, exporte e importe cada shard com `-i`.

### Operações de Ciclo de Vida e Manutenção

| Comando                       | Descrição                                                                                                                                                        |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./dspace.sh install`         | Realiza uma instalação nova do zero, clonando/atualizando os repositórios configurados, construindo as imagens e iniciando todo o ambiente.                  |
| `./dspace.sh migrate`         | Migra uma instalação standalone existente para Docker usando os caminhos e opções de migração configurados.                                                   |
| `./dspace.sh update`          | Atualiza o código-fonte com Git, reconstrói as imagens sem cache e recria o ambiente. O comando para se houver mudanças locais nos repositórios DSpace clonados. |
| `./dspace.sh rebuild`         | Reconstrói as imagens Docker locais mantendo o código atual e recria o ambiente.                                                                                 |
| `./dspace.sh restart`         | Reinicia os containers existentes sem removê-los ou recriá-los.                                                                                                  |
| `./dspace.sh start`           | Inicia os containers existentes.                                                                                                                                 |
| `./dspace.sh stop`            | Para os containers do ecossistema sem remover volumes ou dados.                                                                                                  |
| `./dspace.sh clean-migration` | Remove arquivos temporários de migração depois de uma migração bem-sucedida.                                                                                     |
| `./dspace.sh help`            | Exibe a lista de comandos disponíveis e orientações de uso.                                                                                                      |

O script gera Dockerfiles ajustados em `.docker-build/` em vez de editar diretamente os repositórios upstream clonados.

---

## 4. Comandos Úteis e Operações Granulares

Em cenários de depuração ou manutenção, você pode gerenciar os serviços (`dspacedb`, `dspacesolr`, `dspace`, `dspace-angular`) de forma isolada usando o Docker Compose nativo.

### Gerenciamento de Serviços Individuais

```bash
# Reiniciar apenas o backend do DSpace
docker compose -f docker-compose.prod.yml restart dspace

# Iniciar apenas o Solr
docker compose -f docker-compose.prod.yml up -d dspacesolr

# Parar o frontend Angular SSR
docker compose -f docker-compose.prod.yml stop dspace-angular

```

### Utilitários do DSpace

```bash
# Criar o usuário administrador inicial (CLI do DSpace)
docker exec -it dspace /dspace/bin/dspace create-administrator

# Reindexação do Solr (Discovery)
docker exec -it dspace /dspace/bin/dspace index-discovery -b

# Opcional depois da migração: remover arquivos temporários de migração
./dspace.sh clean-migration

# Verificar a configuração de execução do frontend
docker exec -it dspace-angular cat /app/dist/browser/assets/config.json
docker exec -it dspace-angular cat /app/config/config.yml
docker exec -it dspace-angular env | grep '^DSPACE_' | sort


```

---

## 5. Monitoramento de Logs

### Logs de Saída Padrão do Docker (Stdout)

Para acompanhar a execução do container em tempo real:

```bash
docker logs -f <nome-do-serviço>

# Exemplo para o frontend:
docker logs -f dspace-angular

```

### Logs Internos da Aplicação DSpace

Para rastrear erros de persistência, rotinas do DSpace Core ou depurar a API REST:

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log

```
