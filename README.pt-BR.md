# Gerenciamento do Ambiente DSpace (Produção)

Este repositório centraliza a orquestração e o deploy automatizado da plataforma DSpace (Backend Spring Boot, Frontend Angular SSR, PostgreSQL e Apache Solr) utilizando Docker de forma modular.

---

## 1. Pré-requisitos

Antes de iniciar, garanta que a infraestrutura atenda aos requisitos mínimos de software e permissões de sistema.

### Ferramentas Necessárias

* **Docker Engine** e **Docker Compose Plugin** instalados.
* **Git** instalado.

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
sudo git clone https://github.com/LA-Referencia-Lyrasis-Project/ibict-dspace-docker-deploy.git
sudo chown -R dspace:dspace /opt/ibict-dspace-docker-deploy

```

> ⚠️ **A partir deste ponto, mude para o usuário `dspace`:** 
```bash
sudo su - dspace

### e acesse 
cd /opt/ibict-dspace-docker-deploy

```

### Arquivos de Configuração Ambiente

Crie os arquivos locais com base nos templates do repositório:

```bash
cp .env.example .env
cp local.cfg.example local.cfg

```

1. **Editar o arquivo `.env`:** Configure as variáveis de ambiente (repositórios, tags/branches, credenciais e portas).
2. **⚠️ Atenção Crítica:** Altere a variável `POSTGRES_PASSWORD` no `.env` para uma senha forte antes de iniciar o ambiente.
3. **Editar o arquivo `local.cfg`:** Adicione as propriedades da aplicação DSpace (metadados, SMTP/E-mail, autenticação externa, etc.).

### Regras Importantes para o `local.cfg`

Para evitar conflitos na rede interna do Docker, siga as restrições abaixo:

| Tipo de Propriedade | Chaves Proibidas no `local.cfg` | Motivo / Onde Alterar |
| --- | --- | --- |
| **Fixas pelo Docker** | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server` | **Não alterar**. Valores necessários para a comunicação interna entre os containers. |
| **Gerenciadas via `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Definir apenas no `.env**`. Valores injetados dinamicamente via Compose. |

> 💡 **Nota:** Qualquer alteração futura realizada no arquivo `local.cfg` exige a reinicialização do container backend (`dspace`) para entrar em vigor.

---

## 3. Comandos Disponíveis (`deploy.sh`)

O script `./deploy.sh` gerencia o ciclo de vida da infraestrutura. Ele possui um mecanismo que detecta privilégios `root` na primeira execução para criar estruturas iniciais e delega o restante do processo de forma transparente para o usuário `dspace`.

Garanta a permissão de execução:

```bash
chmod +x deploy.sh

```

### Operações Principais (Executadas apenas uma vez)

* **Instalação Nova do Zero:**
```bash
./deploy.sh install

```


* **Migração de Instalação Existente (Standalone para Docker):**
```bash
./deploy.sh migrate

```



> ⚠️ **Compatibilidade da Migração:** A instalação de origem e o container Docker **devem usar a mesma versão do DSpace** (ex: 9.x para 9.x). Não use o script de migração para atualizar versões (ex: 7.x para 9.x). Atualize o DSpace standalone antes de migrar.

### Operações de Ciclo de Vida e Manutenção

| Comando | Descrição |
| --- | --- |
| `./deploy.sh update` | Atualiza o código-fonte (Git), reconstrói as imagens sem cache e reinicia o ambiente. |
| `./deploy.sh rebuild` | Reconstrói as imagens Docker locais mantendo o código atual e reinicia. |
| `./deploy.sh restart` | Reinicia todos os containers reaproveitando as imagens atuais. |
| `./deploy.sh start` | Inicia os containers existentes. |
| `./deploy.sh stop` | Para os containers do ecossistema sem remover volumes ou dados. |

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

# Verificar o arquivo de configuração ativa gerado pelo frontend
docker exec -it dspace-angular cat /app/src/assets/config.json


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
