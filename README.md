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

1. **Editar el archivo `.env`:** Configure las variables de entorno (repositorios, tags/branches, credenciales y puertos).
2. **⚠️ Atención Crítica:** Cambie la variable `POSTGRES_PASSWORD` en el `.env` por una contraseña fuerte antes de iniciar el entorno por primera vez.
3. **Editar el archivo `local.cfg`:** Añada las propiedades específicas de la aplicación DSpace (metadatos, SMTP/Correo electrónico, autenticación externa, etc.).

### Reglas Importantes para el `local.cfg`

Para evitar conflictos en la red interna de Docker, respete las siguientes restricciones:

| Tipo de Propiedad          | Claves Prohibidas en `local.cfg`                                                  | Motivo / Dónde Modificar                                                                  |
| -------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **Fijas por Docker**       | `dspace.dir`, `dspace.server.ssr.url`, `db.url`, `solr.server`                    | **No modificar**. Valores necesarios para la comunicación interna entre los contenedores. |
| **Gestionadas vía `.env**` | `dspace.name`, `dspace.server.url`, `dspace.ui.url`, `db.username`, `db.password` | **Definir solo en el `.env**`. Valores inyectados dinámicamente mediante Compose.         |

> 💡 **Nota:** Cualquier cambio futuro realizado en el archivo `local.cfg` requerirá el reinicio del contenedor backend (`dspace`) para aplicarse.

---

## 3. Comandos Disponibles (`deploy.sh`)

El script `./deploy.sh` gestiona el ciclo de vida de la infraestructura. Cuenta con un mecanismo que detecta privilegios de `root` en la primera ejecución para crear las estructuras iniciales y delega el resto del proceso de forma transparente al usuario `dspace`.

Asegure el permiso de ejecución:

```bash
chmod +x deploy.sh

```

### Operaciones Principales (Se ejecutan solo una vez)

- **Instalación Nueva desde Cero:**

```bash
./deploy.sh install

```

- **Migración de una Instalación Existente (Standalone a Docker):**

```bash
./deploy.sh migrate

```

> ⚠️ **Compatibilidad de la Migración:** La instalación de origen y el contenedor Docker **deben utilizar la misma versión de DSpace** (ej: 9.x a 9.x). No utilice el script de migración para actualizar versiones (ej: 7.x a 9.x). Actualice el DSpace standalone antes de migrar.

### Operaciones de Ciclo de Vida y Mantenimiento

| Comando               | Descripción                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------- |
| `./deploy.sh update`  | Actualiza el código fuente (Git), reconstruye las imágenes sin caché y reinicia el entorno. |
| `./deploy.sh rebuild` | Reconstruye las imágenes Docker locales manteniendo el código actual y reinicia.            |
| `./deploy.sh restart` | Reinicia todos los contenedores reutilizando las imágenes actuales.                         |
| `./deploy.sh start`   | Inicia los contenedores existentes.                                                         |
| `./deploy.sh stop`    | Detiene los contenedores del ecosistema sin eliminar volúmenes ni datos.                    |

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

# Verificar el archivo de configuración activa generado por el frontend
docker exec -it dspace-angular cat /app/src/assets/config.json

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
