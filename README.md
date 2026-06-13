# Gestión del Entorno DSpace (Producción)

Este repositorio centraliza la orquestación y el despliegue automatizado de la plataforma DSpace (Backend Spring Boot, Frontend Angular SSR, PostgeSQL y Apache Solr) utilizando Docker de forma modular.

Idiomas:

- Español (este documento)
- [Inglés](README.en.md)
- [Portugués](README.pt-BR.md)

---

## Requisitos Previos y Configuración Inicial

Antes de ejecutar el script de despliegue, es obligatorio configurar las variables de entorno que controlarán la clonación de repositorios, la construcción de imágenes y las credenciales de la infraestructura.

### Requisitos Previos

Antes de utilizar este proyecto, asegúrese de cumplir los siguientes requisitos.

#### Docker y Docker Compose

Instale Docker Engine y Docker Compose Plugin siguiendo la documentación oficial de Docker.

Verifique la instalación:

```bash
docker --version
docker compose version
```

#### Git

Git se utiliza para clonar y actualizar automáticamente los repositorios de DSpace y DSpace Angular.

Verifique la instalación:

```bash
git --version
```

#### Usuario con Permisos para Docker

El usuario que ejecutará el script `deploy.sh` debe tener permisos para ejecutar comandos Docker.

Verifique:

```bash
docker ps
```

Si aparece un error de permisos, agregue el usuario al grupo `docker`:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

O cierre e inicie sesión nuevamente.

---

## Instalación Inicial o Migración

⚠️ **Importante:** Los comandos `install` y `migrate` deben ejecutarse únicamente una vez durante la creación inicial del entorno.

Después de la implementación inicial, utilice únicamente los comandos de mantenimiento (`update`, `rebuild`, `restart` y `stop`).

### Opción 1 — Instalación Nueva

Utilice esta opción cuando vaya a desplegar un entorno DSpace completamente nuevo, sin datos existentes.

```bash
./deploy.sh install
```

### Opción 2 — Migración de una Instalación Existente

Utilice esta opción cuando ya exista una instalación DSpace ejecutándose fuera de contenedores (standalone) y desee migrarla a Docker.

```bash
./deploy.sh migrate
```

Durante la migración se transfieren:

- Base de datos PostgreSQL
- Assetstore
- Índices de Solr
- Archivo `local.cfg`

### Requisitos de la Migración

La migración fue diseñada para convertir una instalación DSpace standalone existente en una implementación Docker equivalente.

Para garantizar la compatibilidad, la instalación de origen y la instalación Docker deben utilizar:

- La misma versión de DSpace
- El mismo código fuente
- Las mismas personalizaciones y extensiones
- Configuraciones compatibles

#### Ejemplos

✅ Compatible:

```text
DSpace 10.0 personalizado → DSpace 10.0 personalizado en Docker
```

✅ Compatible:

```text
DSpace 9.1 → DSpace 9.1 en Docker
```

❌ No compatible:

```text
DSpace 8.x → DSpace 10.x
```

❌ No compatible:

```text
DSpace 7.x → DSpace 9.x
```

En estos casos, primero debe realizarse el proceso oficial de actualización de DSpace y posteriormente la migración a Docker.

---

## Configuración Inicial

1. Copia los archivos de ejemplo para crear tu archivo `.env` y tu archivo `local.cfg`:

   ```bash
   cp .env.example .env
   cp local.cfg.example local.cfg
   ```

2. Edite el archivo `.env` con sus configuraciones específicas (repositorios, ramas/tags, credenciales, etc.).

3. Configure el archivo `local.cfg` con las propiedades específicas de DSpace (correo electrónico, autenticación externa, etc.).

4. ⚠️ Atención: Cambie la variable `POSTGRES_PASSWORD` por una contraseña segura antes de iniciar el entorno por primera vez.

---

# Flujo Recomendado

```text
                           Primera Ejecución
                                   │
                  ┌────────────────┴────────────────┐
                  │                                 │
                  ▼                                 ▼
         ./deploy.sh install             ./deploy.sh migrate
                  │                                 │
                  └────────────────┬────────────────┘
                                   ▼
                        Entorno en Producción
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
        ▼                          ▼                          ▼
      update                    rebuild                   restart
        │                          │                          │
 Actualiza código         Reconstruye imágenes      Reinicia contenedores
 e imágenes               sin actualizar código
                                   │
                                   ▼
                                 stop
                                   │
                     Detiene temporalmente el entorno
```

---

## Configuración de DSpace (`local.cfg`)

Además del archivo `.env`, puede configurar el archivo `local.cfg`, que contiene propiedades específicas de la aplicación DSpace.

El archivo `local.cfg` sobrescribe la configuración predeterminada de DSpace y permite personalizar funcionalidades que no están disponibles mediante variables de entorno.

### Ejemplo de Configuración

```properties
# Configuración de correo electrónico
mail.server = smtp.gmail.com
mail.server.username = usuario@dominio.com
mail.server.password = contraseña-o-app-password
mail.server.port = 587
```

### Observaciones

Las propiedades indicadas a continuación son administradas por la implementación Docker y no deben modificarse en el archivo `local.cfg`.

#### Propiedades Fijas

- dspace.dir
- dspace.server.ssr.url
- db.url
- solr.server

Estos valores son necesarios para la comunicación entre los contenedores dentro de la red interna de Docker. Modificarlos puede impedir que DSpace se conecte a PostgreSQL, Solr u otros servicios internos, provocando errores durante el inicio o funcionamiento de la aplicación.

#### Propiedades Administradas por Docker Compose

- dspace.name (proveniente de `DSPACE_NAME`)
- dspace.server.url (proveniente de `DSPACE_SERVER_URL`)
- dspace.ui.url (proveniente de `DSPACE_UI_URL`)
- db.username (proveniente de `POSTGRES_USER`)
- db.password (proveniente de `POSTGRES_PASSWORD`)

Estas configuraciones deben modificarse en el archivo `.env`. Definirlas en `local.cfg` no tendrá efecto, ya que los valores proporcionados por Docker Compose sobrescriben cualquier valor definido en este archivo.

#### Correspondencia entre `local.cfg` y `.env`

- dspace.name ⇔ DSPACE_NAME
- dspace.server.url ⇔ DSPACE_SERVER_URL
- dspace.ui.url ⇔ DSPACE_UI_URL
- db.username ⇔ POSTGRES_USER
- db.password ⇔ POSTGRES_PASSWORD

> Los cambios realizados en `local.cfg` requieren reiniciar el contenedor backend para que surtan efecto.

---

## Script de Despliegue Automatizado (`deploy.sh`)

El script `./deploy.sh` automatiza todo el ciclo de vida de la aplicación.

### Cómo Utilizarlo

Asegúrese de que el script tenga permisos de ejecución:

```bash
chmod +x deploy.sh
```

### Comandos Disponibles

| Comando               | Descripción                                                                 |
| --------------------- | --------------------------------------------------------------------------- |
| `./deploy.sh install` | Instala un nuevo entorno DSpace.                                            |
| `./deploy.sh migrate` | Migra una instalación DSpace standalone existente a Docker.                 |
| `./deploy.sh update`  | Actualiza el código fuente, reconstruye las imágenes y reinicia el entorno. |
| `./deploy.sh rebuild` | Reconstruye las imágenes Docker sin actualizar el código fuente.            |
| `./deploy.sh restart` | Reinicia los contenedores utilizando las imágenes existentes.               |
| `./deploy.sh stop`    | Detiene todos los contenedores del entorno sin eliminarlos.                 |

---

## Gestión Granular de Servicios (Docker Compose)

En tareas de mantenimiento o depuración no es necesario detener todo el ecosistema. Docker Compose permite gestionar servicios individualmente.

### Servicios Disponibles

- **dspacedb**: Base de datos PostgreSQL.
- **dspacesolr**: Motor de búsqueda Apache Solr.
- **dspace**: Backend REST de DSpace.
- **dspace-angular**: Frontend Angular SSR.

### Reiniciar un Servicio

```bash
docker compose -f docker-compose.prod.yml restart dspace
```

### Iniciar un Servicio

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr
```

### Detener un Servicio

```bash
docker compose -f docker-compose.prod.yml stop dspace-angular
```

---

## Registros y Comandos Útiles

### Monitorización de registros de Docker (Salida estándar)

Para ver y monitorizar los registros de salida de un contenedor específico en tiempo real: `docker logs -f <nombre-del-servicio>`

Ejemplo:

```bash
docker logs -f dspace-angular
```

### Ver Registros Internos de DSpace

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log
```

### Ver Configuración Activa del Frontend

```bash
docker exec -it dspace-angular cat /app/src/assets/config.json
```

### Crear un Usuario Administrador

```bash
docker exec -it dspace /dspace/bin/dspace create-administrator
```
