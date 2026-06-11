# Gestión del Entorno DSpace (Producción)

Este repositorio centraliza la orquestación y el despliegue automatizado de la plataforma DSpace (Backend Spring Boot, Frontend Angular SSR y Apache Solr) utilizando Docker de forma modular.

Idiomas:
-  Español (este documento)
-  [Inglés](README.en.md)
- [Portugués](README.pt-BR.md)

---

## Requisitos Previos y Configuración Inicial

Antes de ejecutar el script de despliegue, es obligatorio configurar las variables de entorno que controlarán la clonación de repositorios, la construcción de imágenes y las credenciales de la infraestructura.

1. Copie el archivo de ejemplo para crear su archivo `.env`:

   ```bash
   cp .env.example .env
   ```

2. Edite el archivo `.env` con su configuración específica (repositorios, etiquetas/ramas, credenciales, etc.).

3. ⚠️ Advertencia Crítica: Cambie la variable `POSTGRES_PASSWORD` por una contraseña segura de su preferencia antes de iniciar el entorno por primera vez.

## Script de Despliegue Automatizado (`deploy.sh`)

El script `./deploy.sh` automatiza todo el ciclo de vida de la aplicación. Gestiona las actualizaciones mediante Git, corrige permisos críticos de infraestructura e inyecta parámetros de tolerancia a fallos de red (`MAVEN_OPTS`) para mitigar errores de conexión (`Connection reset`) durante la compilación del backend.

### Uso

Asegúrese de que el script tenga permisos de ejecución:

```bash
chmod +x deploy.sh
```

Ejecute uno de los siguientes comandos (utilice `sudo` si su usuario no pertenece al grupo `docker`):

| Comando               | Descripción                                                                                                                                                        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `./deploy.sh install` | Realiza la clonación inicial de los repositorios (backend/frontend), aplica correcciones de permisos, construye las imágenes y levanta los contenedores.           |
| `./deploy.sh update`  | Accede a cada repositorio, ejecuta `git pull` para obtener el código más reciente, reconstruye todas las imágenes desde cero (`--no-cache`) y reinicia el entorno. |
| `./deploy.sh rebuild` | Fuerza la reconstrucción completa de todas las imágenes Docker locales sin actualizar el código fuente y reinicia los contenedores.                                |
| `./deploy.sh restart` | Elimina y recrea rápidamente todos los contenedores sin modificar las imágenes ni el código. Útil para aplicar cambios en el archivo `.env`.                       |

## 🛠️ Gestión Granular de Servicios (Docker Compose)

Durante tareas de mantenimiento o depuración, no es necesario detener todo el ecosistema. Docker Compose permite detener, iniciar o reiniciar servicios de manera individual.

> Nota sobre permisos: Si es necesario, agregue el prefijo `sudo` a los comandos `docker` y `docker compose`.

### Servicios Disponibles

* **`dspacedb`**: Base de datos PostgreSQL donde se almacenan los metadatos y esquemas.
* **`dspacesolr`**: Motor de búsqueda Apache Solr (núcleos de búsqueda, estadísticas y autoridad).
* **`dspace`**: Backend de la aplicación (API REST Spring Boot embebida).
* **`dspace-angular`**: Frontend de la aplicación ejecutándose en modo Server-Side Rendering (SSR) con Node.js.

### Detener y Eliminar un Servicio Específico

```bash
docker compose -f docker-compose.prod.yml down <nombre-del-servicio>
```

Ejemplo:

```bash
docker compose -f docker-compose.prod.yml down dspace-angular
```

### Crear e Iniciar un Servicio Específico

```bash
docker compose -f docker-compose.prod.yml up -d <nombre-del-servicio>
```

Ejemplo:

```bash
docker compose -f docker-compose.prod.yml up -d dspacesolr
```

### Reiniciar un Servicio Específico

```bash
docker compose -f docker-compose.prod.yml restart <nombre-del-servicio>
```

Ejemplo:

```bash
docker compose -f docker-compose.prod.yml restart dspace
```

## Logs y Comandos Útiles

> Nota sobre permisos: Si es necesario, agregue el prefijo `sudo` a los comandos `docker` y `docker compose`.

### Supervisión de Logs de Docker

```bash
docker logs -f <nombre-del-servicio>

# Ejemplo para el frontend
docker logs -f dspace-angular
```

### Supervisión de Logs Internos de DSpace

```bash
docker exec -it dspace tail -f /dspace/log/dspace.log
```

### Verificar la Configuración Activa del Frontend

```bash
docker exec -it dspace-angular cat /app/src/assets/config.json
```

### Crear un Usuario Administrador (E-Person)

```bash
docker exec -it dspace /dspace/bin/dspace create-administrator
```
