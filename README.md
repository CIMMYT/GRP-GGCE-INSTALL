# 🖥️ cimmyt-ggce-tool

Este script es el punto de entrada principal para la herramienta de despliegue de GGCE desarrollada por CIMMYT.

Automatiza la configuración, instalación y gestión de los servicios Docker requeridos por la aplicación [GGCE](https://ggce.genesys-pgr.org) (Germplasm Global Community Edition) .


## 📌 Compatibilidad
✅ Compatible únicamente con sistemas Linux, específicamente Debian y Ubuntu (basados en APT y dpkg).

## ⚙️ Funcionalidad
El script realiza las siguientes funciones principales:

* Carga los módulos necesarios (environment.sh, deployment.sh, ui.sh).

* Gestiona la instalación interactiva de GGCE.

* Administra los contenedores Docker de la aplicación (iniciar, detener, reiniciar).

* Muestra información de versión basada en metadatos del paquete .deb.

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

### 🔧 -s o --server <acción>
Administra los contenedores de GGCE. Las acciones disponibles son:

|Acción	|Descripción|
|---|---|
|--start |	Inicia todos los servicios|
|--stop |	Detiene y elimina los contenedores|
|--restart |	Reinicia los servicios|

Ejemplos:

```bash
cimmyt-ggce-tool --server --start
cimmyt-ggce-tool --server --stop
cimmyt-ggce-tool --server --restart
```
### 📄 -v o --version
Muestra la información de versión del paquete (.deb) y la descripción del programa, si fue instalado con dpkg.

## 🛑 Consideraciones importantes
* La herramienta requiere privilegios de root para instalar y gestionar los servicios.

* Si una instalación previa existe, se solicitará confirmación explícita para sobrescribirla.

* El asistente de instalación valida contraseñas y formatos de memoria antes de guardar la configuración.

## 💡 Ejemplo de uso
```bash
sudo cimmyt-ggce-tool --install
```
```bash
sudo cimmyt-ggce-tool --server --start
```
