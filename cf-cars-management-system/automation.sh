#!/bin/bash

#modo depuracion descomentar el set -x
set -x

#Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#Variables
TEMP_DIR="tempdir"
DOCKER_IMAGE="cars-management-app"
CONTAINER_NAME="cars-management-container"
PORT=3000
APP_VERSION="1.0.0"
DOCKERFILE_PATH="Dockerfile"

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

#
check_tools() {
    if command -v docker &>/dev/null; then
    print_message $GREEN "Docker está instalado."
    else
    print_message $RED "Docker no está instalado."
    exit 1
    fi
}

check_tools

#Leer version desde package.json
if [ -f package.json ]; then
    APP_VERSION=$(jq -r '.version' package.json)
    print_message $GREEN "Versión de la aplicación leída desde package.json: $APP_VERSION"
else
    print_message $YELLOW "package.json no encontrado. Usando versión por defecto: $APP_VERSION"
fi

#Eliminar contenedores en ejecucion
print_message $YELLOW "Eliminando contenedores antiguos..."
docker rm -f $CONTAINER_NAME
docker rmi -f $DOCKER_IMAGE  

#Estructura de directorio
print_message $GREEN "Creando estructura de directorios..."
mkdir -p $TEMP_DIR/{public,src}
cp -r src/* $TEMP_DIR/src/
cp -r public/* $TEMP_DIR/public/
cp package*.json server.js $TEMP_DIR/


#Crear Dockerfile
print_message $GREEN "Creando Dockerfile..."
cat <<EOF > $TEMP_DIR/Dockerfile
FROM node:18-alpine
LABEL org.opencontainers.image.authors="RoxsRoss"
RUN apk add --update python3 make bash g++\
&& rm -rf /var/cache/apk/*
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOF


#Construir imagen Docker
print_message $YELLOW "Construyendo imagen Docker..."
docker build -t $DOCKER_IMAGE:$APP_VERSION $TEMP_DIR

#Iniciar el contenedor
print_message $YELLOW "Iniciando el contenedor..."
docker run -d -p $PORT:$PORT --name $CONTAINER_NAME $DOCKER_IMAGE:$APP_VERSION

#Ver los logs
print_message $RED "Mostrando logs del contenedor..."
docker logs $CONTAINER_NAME

#Mostrar IP del contenedor
print_message $GREEN "Obteniendo dirección IP del contenedor..."
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME)
print_message $GREEN "La dirección IP del contenedor es: $CONTAINER_IP"

#Probar la aplicacion
print_message $YELLOW "Probando la aplicación..."
if curl -s http://$CONTAINER_IP:$PORT > /dev/null; then
    print_message $GREEN "La aplicación está funcionando correctamente. Con el puerto:$PORT"
fi

#Limpieza de directorio
print_message $YELLOW "Limpiando directorios temporales..."
rm -rf $TEMP_DIR

set +x
