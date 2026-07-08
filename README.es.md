# Gestión del Entorno DSpace (Producción)

Este repositorio centraliza la orquestación y el despliegue automatizado de la plataforma DSpace (Backend Spring Boot, Frontend Angular SSR, PostgreSQL y Apache Solr) utilizando Docker de forma modular.

---

## 1. Requisitos Previos

Antes de iniciar, asegúrese de que la infraestructura cumpla con los requisitos mínimos de software y permisos de sistema.

### Herramientas Necesarias

- **Docker Engine** y **Docker Compose Plugin** instalados.
- **Git** instalado.

Verifique las versiones con los siguientes comandos:

```bash
docker --version
docker compose version
git --version

```

### Configuración del Usuario del Sistema

Por motivos de seguridad en entornos de producción, cree un usuario dedicado llamado `dspace` y agréguelo al grupo de Docker:

```bash
# Crea el usuario de sistema 'dspace' con directorio home
sudo useradd -m -s /bin/bash dspace

# Define una contraseña para el usuario
sudo passwd dspace

# Añade el usuario al grupo docker
sudo usermod -aG docker dspace
newgrp docker

```

---

## 2. Clonación y Configuración Inicial

### Descarga del Proyecto

Navegue hasta el directorio `/opt`, clone el repositorio y ajuste los permisos para el usuario creado:

```bash
cd /opt
sudo git clone https://github.com/LA-Referencia-Lyrasis-Project/lareferencia-dspace-docker-deploy.git
sudo chown -R dspace:dspace /opt/lareferencia-dspace-docker-deploy

```

> ⚠️ **A partir de este punto, cambie al usuario `dspace`:**

```bash
sudo su - dspace

# y acceda
cd /opt/lareferencia-dspace-docker-deploy

```

### Archivos de Configuración del Entorno

Cree los archivos locales basados en las plantillas del repositorio:

```bash
cp .env.example .env
cp local.cfg.example local.cfg

```

1. **Editar el archivo `.env`:** Configure las variables de entorno (repositorios, tags/branches, credenciales, puertos, subnet Docker y opciones de migración).
2. **⚠️ Atención Crítica:** Cambie la variable `POSTGRES_PASSWORD` en el `.env` por una contraseña fuerte antes de iniciar el entorno por primera vez.
3. **Editar el archivo `local.cfg`:** Añada las propiedades específicas de la aplicación DSpace (metadatos, SMTP/Correo electrónico, autenticación externa, etc.).

El script de despliegue lee el `.env` como datos y no ejecuta el archivo como script shell. Use líneas en formato `KEY=value` y coloque entre comillas los valores que contengan espacios.

### Reglas Importantes para el `local.cfg`

Para evitar conflictos en la red interna de Docker, respete las siguientes restricciones:

| Tipo de Propiedad          | Claves Prohibidas en `local.cfg`                                                  | Motivo / Dónde Modificar                                                                  |
| -------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Fijas por Docker**       | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server`                    | **No modificar**. Valores necesarios para la comunicación interna entre los contenedores. |
| **Gestionadas vía `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Definir solo en el `.env**`. Valores inyectados dinámicamente mediante Compose.         |

> 💡 **Nota:** Cualquier cambio futuro realizado en el archivo `local.cfg` requerirá el reinicio del contenedor backend (`dspace`) para aplicarse.

---

## 3. Comandos Disponibles (`dspace.sh`)

El script `./dspace.sh` gestiona el ciclo de vida de la infraestructura. Ejecútelo como el usuario dedicado `dspace` después de que ese usuario tenga permisos para usar Docker.

Asegure el permiso de ejecución:

```bash
chmod +x dspace.sh

```

### Operaciones Principales (Se ejecutan solo una vez)

- **Instalación Nueva desde Cero:**

```bash
./dspace.sh install

```

- **Migración de una Instalación Existente (Standalone a Docker):**

```bash
./dspace.sh migrate

```

#### Migración

> ⚠️ **Compatibilidad de la Migración:** La instalación de origen y el contenedor Docker **deben utilizar la misma versión de DSpace** (ej: 9.x a 9.x). No utilice el script de migración para actualizar versiones (ej: 7.x a 9.x). Actualice el DSpace standalone antes de migrar.

La migración requiere volúmenes Docker vacíos para PostgreSQL, assetstore y Solr. Si un intento anterior falla, inspeccione los volúmenes antes de eliminar `.lock_in_progress` y volver a intentar.

Por defecto, los datos heredados de Solr no se copian (`MIGRATE_SOLR_DATA=false`). Este es el camino recomendado para la mayoría de las migraciones; inicie el entorno y ejecute la reindexación de DSpace después de migrar. Use `MIGRATE_SOLR_DATA=true` solo cuando realmente necesite copiar cores antiguos de Solr.

Cuando `MIGRATE_SOLR_DATA=false`, conserve solo los datos necesarios de Solr mediante una exportación lógica, sin copiar los directorios físicos de los cores. Antes de ejecutar la migración, ejecute en el DSpace actual:

```bash
mkdir -p /tmp/dspace-solr-export
[dspace]/bin/dspace solr-export-statistics -i authority -d /tmp/dspace-solr-export -f
[dspace]/bin/dspace solr-export-statistics -i statistics -d /tmp/dspace-solr-export -f
```

Después de la migración, con el entorno Docker iniciado y el Solr nuevo vacío, reindexe Discovery e importe los datos exportados:

```bash
docker exec -it dspace /dspace/bin/dspace index-discovery -b
docker cp /tmp/dspace-solr-export dspace:/tmp/dspace-solr-export
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i authority -d /tmp/dspace-solr-export -c
docker exec -it dspace /dspace/bin/dspace solr-import-statistics -i statistics -d /tmp/dspace-solr-export -c
```

Use `-c` solo cuando el core de destino pueda limpiarse antes de la importación. Si la instalación antigua tiene shards de estadísticas, como `statistics-2024`, exporte e importe cada shard con `-i`.

### Operaciones de Ciclo de Vida y Mantenimiento

| Comando                       | Descripción                                                                                                                                                                       |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `./dspace.sh install`         | Realiza una instalación nueva desde cero, clonando/actualizando los repositorios configurados, construyendo las imágenes e iniciando todo el entorno.                        |
| `./dspace.sh migrate`         | Migra una instalación standalone existente a Docker usando las rutas y opciones de migración configuradas.                                                                       |
| `./dspace.sh update`          | Actualiza el código fuente con Git, reconstruye las imágenes sin caché y recrea el entorno. El comando se detiene si existen cambios locales en los repositorios DSpace clonados. |
| `./dspace.sh rebuild`         | Reconstruye las imágenes Docker locales manteniendo el código actual y recrea el entorno.                                                                                         |
| `./dspace.sh restart`         | Reinicia los contenedores existentes sin eliminarlos ni recrearlos.                                                                                                               |
| `./dspace.sh start`           | Inicia los contenedores existentes.                                                                                                                                               |
| `./dspace.sh stop`            | Detiene los contenedores del ecosistema sin eliminar volúmenes ni datos.                                                                                                          |
| `./dspace.sh health`          | Verifica si Solr, PostgreSQL, servidor backend e interfaz UI están saludables y accesibles.                                                                                      |
| `./dspace.sh clean-migration` | Elimina archivos temporales de migración después de una migración exitosa.                                                                                                        |
| `./dspace.sh help`            | Muestra la lista de comandos disponibles y la guía de uso.                                                                                                                         |

El script genera Dockerfiles ajustados en `.docker-build/` en lugar de editar directamente los repositorios upstream clonados.

---

## 4. Comandos Útiles y Operaciones Granulares

En escenarios de depuración o mantenimiento, puede gestionar los servicios (`dspacedb`, `dspacesolr`, `dspace`, `dspace-angular`) de forma aislada utilizando Docker Compose nativo.

### Gestión de Servicios Individuales

```bash
# Reiniciar solo el backend de DSpace
docker compose -f docker-compose.prod.yml restart dspace

# Iniciar solo el Solr
docker compose -f docker-compose.prod.yml up -d dspacesolr

# Detener el frontend Angular SSR
docker compose -f docker-compose.prod.yml stop dspace-angular

```

### Utilidades de DSpace

```bash
# Crear el usuario administrador inicial (CLI de DSpace)
docker exec -it dspace /dspace/bin/dspace create-administrator

# Reindexación de Solr (Discovery)
docker exec -it dspace /dspace/bin/dspace index-discovery -b

# Opcional después de la migración: eliminar archivos temporales de migración
./dspace.sh clean-migration

# Verificar la salud general de los servicios (DB, Solr, Servidor, UI)
./dspace.sh health

# Verificar la configuración de ejecución del frontend
docker exec -it dspace-angular cat /app/dist/browser/assets/config.json
docker exec -it dspace-angular cat /app/config/config.yml
docker exec -it dspace-angular env | grep '^DSPACE_' | sort

```

---

## 5. Monitoreo de Logs

### Logs de Salida Estándar de Docker (Stdout)

Para seguir la ejecución del contenedor en tiempo real:

```bash
docker logs -f <nombre-del-servicio>

# Ejemplo para el frontend:
docker logs -f dspace-angular

```

### Logs Internos de la Aplicación DSpace

Para rastrear errores de persistencia, rutinas del DSpace Core o depurar la API REST:

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log

```

---

## 6. Contribuciones

Las contribuciones son bienvenidas.

Si encuentra un error o desea solicitar una funcionalidad, por favor abra un issue con el mayor contexto posible.

Si desea contribuir con código, envíe un Pull Request con una descripción clara de sus cambios.
