# Proyecto ZeroQ Local

Este repositorio contiene la configuración para ejecutar el entorno de desarrollo local de ZeroQ utilizando Docker Compose.

## Requisitos Previos

- Docker instalado ([Instrucciones de instalación](https://docs.docker.com/get-docker/))
- Docker Compose instalado (usualmente viene con Docker Desktop)

## Configuración Inicial

1.  **Obtener el archivo `.env`**: Este archivo contiene variables de entorno necesarias para la aplicación y será proporcionado por privado.
2.  **Ubicar el archivo `.env`**: Copia el archivo `.env` que recibiste y pégalo en el directorio raíz de este repositorio (al mismo nivel que el archivo `docker-compose.yml`).

## Ejecución

Una vez que tengas el archivo `.env` en la raíz del proyecto, puedes iniciar todos los servicios utilizando el siguiente comando en tu terminal, desde el directorio raíz del repositorio:

```bash
docker-compose down && docker-compose up -d
```

**Explicación del comando:**

- `docker-compose down`: Detiene y elimina los contenedores, redes y volúmenes creados previamente por `docker-compose up`. Esto asegura un inicio limpio.
- `docker-compose up -d`: Crea e inicia los contenedores en segundo plano (`-d`, detached mode).

Los servicios (backend, base de datos, redis, etc.) estarán disponibles una vez que el comando termine de ejecutarse. Puedes verificar los logs de los contenedores con `docker-compose logs -f`.

## Actualización de la Imagen

Si el equipo de ZeroQ actualiza la imagen Docker (`docker.zeroq.cl/zeroq-local:latest-v3-qa`) en el registro (por ejemplo, publicando una nueva versión con la misma etiqueta), necesitarás descargar la versión más reciente de la imagen antes de reiniciar tus contenedores.

Puedes hacerlo ejecutando los siguientes comandos:

```bash
# 1. Descargar la última versión de la imagen especificada en docker-compose.yml
docker-compose pull

# 2. Detener y reiniciar los contenedores para usar la nueva imagen
docker-compose down && docker-compose up -d
```

Esto asegurará que estés utilizando la versión más reciente de la imagen proporcionada por ZeroQ.
