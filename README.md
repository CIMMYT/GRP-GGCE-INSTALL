# CIMMYT ggce-tool

Este script es el punto de entrada principal para la herramienta de despliegue de GGCE desarrollada por [CIMMYT](https://www.cimmyt.org).

Automatiza la configuración, instalación y gestión de los servicios Docker requeridos por la aplicación [GGCE](https://ggce.genesys-pgr.org) (Germplasm Global Community Edition).

## 📌 Compatibilidad
✅ Compatible únicamente con sistemas Linux, específicamente Debian y Ubuntu (basados en APT y dpkg).

## ✅ Prerrequisitos

Antes de utilizar esta herramienta, asegúrese de que los siguientes componentes estén instalados en su sistema:

-   **Docker Engine**: Para la gestión de contenedores.
-   **Docker Compose (plugin)**: Para orquestar los servicios multi-contenedor. La herramienta verifica `docker compose version`.
-   **jq**: Necesario para procesar datos JSON durante el proceso de actualización (`-u`).
-   **Bash**: El intérprete de comandos para ejecutar los scripts.

## ⚙️ Funcionalidad
El script realiza las siguientes funciones principales:

*   Carga los módulos necesarios (environment.sh, deployment.sh, ui.sh).
*   Gestiona la instalación interactiva de GGCE.
*   Administra los contenedores Docker de la aplicación (iniciar, detener, reiniciar, actualizar).
*   Muestra información de versión basada en metadatos del paquete .deb.

## 📁 Rutas utilizadas
|Ruta	|Propósito|
|---|---|
|/usr/lib/cimmyt-ggce-tool/	|Contiene la lógica del sistema (scripts Bash)|
|/etc/cimmyt-ggce-tool/	|Archivo de configuración generado (config.env)|
|/usr/share/cimmyt-ggce-tool/|	Plantillas y recursos estáticos|

## 🚀 Comandos disponibles
```bash
cimmyt-ggce-tool [comando] [opciones]
```
### 📦 -i o --install
Inicia el asistente interactivo de instalación:

* Verifica que el usuario tenga privilegios de superusuario.

* Solicita confirmación si ya existe una instalación previa.

* Genera el archivo de configuración config.env.

* Valida e implementa los recursos necesarios (redes, volúmenes, imágenes Docker).

* Inicia los contenedores asociados.

### 🔄 -u o --update
Busca nuevas versiones disponibles para los componentes de GGCE (API y UI) y permite al usuario seleccionar cuál instalar. Este proceso:
1.  Detiene temporalmente los servicios de la aplicación (API y UI).
2.  Descarga la lista de versiones disponibles.
3.  Permite al usuario seleccionar las versiones a través de un menú interactivo.
4.  Actualiza el archivo `config.env` con las nuevas versiones.
5.  Reinicia los servicios de la aplicación.

### 🔧 -s o --server <acción>
Administra los contenedores de GGCE. Las acciones disponibles son:

|Acción	|Descripción|
|---|---|
|--start |	Inicia únicamente los servicios de la aplicación (API y UI). No inicia la base de datos.|
|--stop |	Detiene únicamente los servicios de la aplicación (API y UI).|
|--restart |	Reinicia los servicios de la aplicación (API y UI).|
|--start-all | Inicia todos los servicios, incluyendo la base de datos (`ggce-mssql`).|
|--stop-all | Detiene y elimina **todos** los contenedores de la aplicación, incluyendo la base de datos.|

### 📄 -v o --version
Muestra la información de versión del paquete (.deb) y la descripción del programa, si fue instalado con dpkg.

## 🛑 Consideraciones importantes
* La herramienta requiere privilegios de root para instalar y gestionar los servicios.

* Si una instalación previa existe, se solicitará confirmación explícita para sobrescribirla.

* El asistente de instalación valida contraseñas y formatos de memoria antes de guardar la configuración.

## 💡 Ejemplo de uso
Instalar la aplicación por primera vez:
```bash
sudo cimmyt-ggce-tool --install
```
```bash
sudo cimmyt-ggce-tool --server --start
```

## Extras

Para conocer más información, puede consultar la [documentación oficial](https://ggce.genesys-pgr.org/docs/install/). Asimismo, es posible agregar más componentes a los archivos de configuración o al propio archivo de `docker-compose ubicado en user/lib/cimmyt-ggce-tool/docker/compose.yml`.


Autor: Juan Carlos Moreno Sanchez 
* <j.m.sanchez@cgiar.org> 
* <j.m.sanchez@cimmyt.org>