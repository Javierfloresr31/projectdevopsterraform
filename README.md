# Infraestructura DevOps en Azure con Terraform

Repositorio de infraestructura como código (IaC) para aprovisionar recursos de Azure y preparar el despliegue de una aplicación Java empaquetada en Docker. El proyecto integra Terraform, Azure Container Apps, Azure Key Vault, Azure SQL Database, Docker Hub y Jenkins.

> **Estado documentado:** esta guía describe los recursos y flujos definidos en los archivos versionados del repositorio. La existencia de una definición Terraform no garantiza por sí sola que el recurso esté desplegado en Azure. La creación real debe verificarse con `terraform apply` y en el portal de Azure.

## 1. Arquitectura general

El proceso de entrega de la aplicación se realiza en dos ejecuciones consecutivas y controladas:

1. **Desarrollo de la aplicación:** se actualiza el código fuente Java en el repositorio [`projectdevopsjava`](https://github.com/Javierfloresr31/projectdevopsjava), en la rama `main).
2. **Integración continua (Jenkins):** se ejecuta manualmente el pipeline de Jenkins. Este clona la rama `main` del repositorio Java, obtiene el SHA del commit, construye la imagen Docker y la publica en Docker Hub (`javierfloresr31/myapp`) usando ese SHA como etiqueta.
3. **Despliegue de infraestructura/aplicación (Terraform):** después de que Jenkins termina correctamente la publicación, se ejecuta `terraform apply` desde este repositorio. Durante la evaluación de la configuración, Terraform consulta la API de Docker Hub, obtiene la etiqueta con la actualización más reciente del repositorio y construye la referencia de imagen que usará el recurso Azure Container App. Al aplicar los cambios, Azure Container Apps se crea o actualiza con esa imagen.

Vista del flujo:

```text
  Desarrollo / actualización Java
                 |
                 v
    GitHub: projectdevopsjava
             rama main
                 |
                 v
       Ejecución manual Jenkins
          (pipeline CI)
                 |
          +------+------+
          |             |
       git clone     SHA commit
          |             |
          +------+------+
                 |
             docker build
                 |
                 v
      Docker Hub: javierfloresr31/myapp
           etiqueta = SHA
                 |
       Jenkins finaliza correctamente
                 |
                 v
     Ejecución manual: terraform apply
                 |
         Terraform consulta
           Docker Hub API
                 |
       identifica última etiqueta
                 |
                 v
       Azure Container Apps
       actualiza/usa esa imagen
                 |
       +---------+----------+
       |                    |
       v                    v
   Azure Key Vault       Azure SQL
     (secretos)           (datos)
```

**Relación entre ambos repositorios:**

- [`projectdevopsjava`](https://github.com/Javierfloresr31/projectdevopsjava) contiene el código fuente de la aplicación Java y su Dockerfile.
- [`projectdevopsterraform`](https://github.com/Javierfloresr31/projectdevopsterraform) contiene la infraestructura como código y el Jenkinsfile que construye y publica la imagen del proyecto Java.
- Docker Hub actúa como registro de imágenes entre la etapa de CI y el despliegue en Azure.

**Importante:** Jenkins y Terraform se ejecutan en momentos distintos. Jenkins no lanza `terraform apply` ni realiza el despliegue en Azure. La publicación de una imagen en Docker Hub tampoco actualiza por sí sola el Container App: es necesario ejecutar `terraform apply` después de que Jenkins haya finalizado correctamente. La consulta de Docker Hub selecciona la etiqueta con la actualización más reciente, por lo que el `terraform apply` debe ejecutarse después de la publicación deseada.

## 2. Tecnologías y componentes

- **Terraform:** aprovisionamiento declarativo de infraestructura.
- **AzureRM Provider 4.4.0:** proveedor de Terraform para Azure.
- **HTTP Provider 3.5.0:** consulta de la API pública de Docker Hub.
- **Azure Container Apps:** ejecución de la imagen Docker en un entorno administrado.
- **Azure Key Vault:** almacenamiento centralizado de secretos y autorización mediante Azure RBAC.
- **Managed Identity (User Assigned):** identidad asignada al Container App para acceder a secretos.
- **Azure SQL Server / Azure SQL Database:** servicio relacional de datos.
- **Docker / Docker Hub:** empaquetado y distribución de la aplicación.
- **Jenkins:** automatización de checkout, build y push de la imagen.
- **GitHub:** repositorios de código fuente.

## 3. Recursos de Azure definidos con Terraform

Los nombres concretos se parametrizan en `terraform.tfvars`; los nombres globalmente únicos, como los de Key Vault y SQL Server, pueden necesitar ajustes según disponibilidad.

| Componente | Definición y propósito |
|---|---|
| Resource Group | Grupo `rg-project-dev-westus2-001`, en la región indicada por `location` (`westus2`). |
| Container Apps Environment | Entorno administrado `cae-project-dev-westus2-001`, con perfil de workload Consumption. |
| Azure Container App | Aplicación `ca-project-dev-westus2-001`, revisión Single, ingress externo por el puerto 8080 y conexiones HTTPS (no se permiten conexiones inseguras). |
| User Assigned Managed Identity | Identidad `id-project-dev-westus2-001` asociada al Container App. |
| Azure Key Vault | Cuatro bóvedas (`kv_01` a `kv_04`) con SKU Standard y autorización basada en Azure RBAC. |
| Role Assignments | La identidad de la aplicación recibe el rol Key Vault Secrets User en las cuatro bóvedas. La identidad del usuario que aplica Terraform recibe Key Vault Administrator en ellas. |
| Azure SQL Server | Servidor SQL con TLS mínimo 1.2 y acceso público habilitado. |
| Azure SQL Database | Base de datos con SKU Basic y tamaño máximo configurado de 2 GB. |
| SQL Firewall Rule | Regla `AllowAzureServices`, que habilita el acceso desde servicios Azure mediante la regla especial 0.0.0.0. |
| Virtual Network | Red virtual `10.0.0.0/16`. |
| Subnet | Subred `10.0.2.0/24`. |
| Network Interface | NIC con dirección privada dinámica y asociación a la IP pública definida. |
| Public IP | IP pública estática. |
| Network Security Group | Reglas de entrada para SSH (22), HTTP (80), HTTPS (443), 8080 y 8081. |
| Output | Expone el valor de la dirección IP pública mediante `terraform output`. |

### 3.1 Container Apps

El recurso de Container Apps se define en `container_app_env.tf`. Utiliza la imagen calculada en `dockerhub.tf`, asigna la identidad administrada y establece:

- Modo de revisión: `Single`.
- Perfil de workload: `Consumption`.
- CPU: 0.25 vCPU.
- Memoria: 0.5 GiB.
- Réplicas mínimas: 1.
- Ingress externo habilitado en el puerto 8080.
- Conexiones inseguras deshabilitadas.

El entorno utiliza el perfil indicado por `cae_01_workload_profile`. El nombre de la imagen se obtiene de Docker Hub consultando la etiqueta con fecha de actualización más reciente del repositorio indicado por `aca_01_image`.

**Importante:** la configuración de ingress permite acceso externo a la aplicación. Deben añadirse controles de autenticación y autorización en la propia aplicación y evaluarse las restricciones de exposición necesarias para el entorno.

### 3.2 Identidad administrada y Key Vault

`identity_user_assigned.tf` crea una identidad de usuario y asigna permisos RBAC. El Container App utiliza esa identidad para consumir secretos de Key Vault sin tener que incluir credenciales de Azure en la imagen.

Los cuatro Key Vault se declaran en `keyvault.tf`, con estas propiedades principales:

- SKU Standard.
- Autorización mediante Azure RBAC.
- Retención de eliminación temporal de 7 días.
- Protección contra purga deshabilitada.
- Acceso de red pública habilitado.

La identidad administrada recibe `Key Vault Secrets User`. El usuario autenticado que ejecuta Terraform recibe `Key Vault Administrator`.

El código declara los permisos, pero no crea automáticamente los secretos de aplicación. Estos deben cargarse en Key Vault y configurarse como referencias en Container Apps. El recurso actual ignora cambios en `secret` y variables de entorno del contenedor, por lo que esos elementos pueden requerir configuración adicional fuera del bloque administrado por Terraform.

### 3.3 Azure SQL

`sql_server.tf` configura un servidor Azure SQL y una base de datos Basic de 2 GB. La región SQL se parametriza independientemente de la región del grupo de recursos y, en la configuración de ejemplo, se establece como `centralus`.

La regla `AllowAzureServices` facilita la conectividad desde servicios Azure, pero no restringe el acceso exclusivamente a esta Container App. Es una configuración de desarrollo y no sustituye una estrategia de red privada.

El archivo `sql/create_app_user.sql`:

- Crea `dbo.Users` si no existe, con las columnas `Id`, `Name` y `Email`.
- Inserta tres registros de ejemplo sin duplicarlos al volver a ejecutar el script.
- Crea el usuario SQL `appreader` si no existe.
- Asigna a `appreader` el rol `db_datareader`.

El script contiene un marcador de posición para la contraseña de `appreader`. Debe sustituirse por una contraseña segura al ejecutarlo y nunca publicarse una contraseña real en el repositorio.

La documentación `Azure-SQL.md` explica el aprovisionamiento, la preparación del usuario de aplicación y los aspectos de conectividad.

## 4. Jenkins y Docker

El repositorio ofrece dos alternativas documentadas para levantar Jenkins en Ubuntu:

- `install.sh`: instala Docker Engine y sus complementos desde el repositorio oficial de Docker, configura el servicio y levanta Jenkins.
- `Dockerfile.jenkins` junto con `Jenkins-Docker.md`: construye una imagen basada en Jenkins LTS que incorpora el cliente Docker y ejecuta Jenkins en un contenedor.

Ambas alternativas usan el volumen Docker `jenkins_home` para conservar trabajos, plugins, usuarios y credenciales aunque se elimine el contenedor.

La interfaz web se publica en el puerto 8080. La contraseña inicial se consulta dentro del contenedor:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Para utilizar Docker desde los pipelines, el contenedor Jenkins monta `/var/run/docker.sock` y se añade al grupo propietario del socket.

> **Advertencia de seguridad:** montar el socket Docker concede a Jenkins capacidad de controlar el daemon del host y puede equivaler a privilegios de administrador/root. Limita el acceso al Jenkins y a los pipelines de confianza. No publiques el volumen `jenkins_home`, ya que contiene información sensible.

Las instrucciones detalladas de instalación, persistencia, operación, respaldo y restauración se encuentran en `Jenkins-Docker.md`.

## 5. Pipeline CI: construcción y publicación

El archivo `jenkinsfile` define el pipeline de la aplicación Java alojada en:

[`Javierfloresr31/projectdevopsjava`](https://github.com/Javierfloresr31/projectdevopsjava)

El pipeline utiliza la rama `main` y ejecuta estas etapas:

1. **Checkout:** elimina una copia previa, clona el repositorio Java y obtiene el SHA del commit.
2. **Build Image:** construye la imagen Docker desde el Dockerfile del repositorio Java y la etiqueta con el SHA del commit.
3. **Push Docker Hub:** publica la imagen en `javierfloresr31/myapp` con esa etiqueta.
4. **Post:** informa el resultado y elimina la carpeta clonada, tanto en éxito como en fallo.

La etiqueta basada en el SHA permite relacionar la imagen publicada con el commit de código fuente que la produjo.

El pipeline presupone que el agente Jenkins dispone de Git, Docker y acceso al repositorio y a Docker Hub. Para publicar en un repositorio privado o cuando Docker Hub lo requiera, configura las credenciales en Jenkins Credentials y realiza un `docker login` seguro; no escribas tokens ni contraseñas directamente en el Jenkinsfile.

**Alcance actual:** el pipeline termina al publicar la imagen. No incluye una etapa de despliegue, actualización de Container Apps, aprobación manual ni ejecución de `terraform apply`.

## 6. Estructura del repositorio

| Archivo | Responsabilidad |
|---|---|
| `provider.tf` | Versiones y configuración de los proveedores Terraform AzureRM y HTTP. |
| `variables.tf` | Variables de nombres, región, identidad, Key Vault, Container Apps y SQL. |
| `terraform.tfvars` | Valores de configuración del entorno de desarrollo. |
| `resource_group.tf` | Grupo de recursos de Azure. |
| `container_app_env.tf` | Container Apps Environment y Container App. |
| `dockerhub.tf` | Obtiene la etiqueta más reciente de Docker Hub y construye la referencia de imagen. |
| `identity_user_assigned.tf` | Identidad administrada y asignaciones RBAC. |
| `keyvault.tf` | Cuatro instancias de Azure Key Vault. |
| `sql_server.tf` | Servidor SQL, base de datos y regla de firewall. |
| `networking.tf` | VNet, subnet y NIC. |
| `ip_public.tf` | Dirección IP pública estática. |
| `net_sec_group.tf` | Network Security Group y asociación a la NIC. |
| `output.tf` | Salida de la IP pública. |
| `sql/create_app_user.sql` | Tabla de ejemplo, registros iniciales y usuario de lectura. |
| `jenkinsfile` | Pipeline de checkout, build y push de la aplicación Java. |
| `Dockerfile.jenkins` | Imagen Jenkins LTS con cliente Docker. |
| `install.sh` | Instalación de Docker y ejecución de Jenkins en Ubuntu. |
| `Jenkins-Docker.md` | Manual de instalación y operación de Jenkins en Docker. |
| `Azure-SQL.md` | Manual de configuración y uso de Azure SQL. |
| `.terraform.lock.hcl` | Versiones y hashes de proveedores seleccionados por Terraform. |
| `.gitignore` | Exclusiones para estado local, directorios Terraform, archivos temporales y claves SSH. |

## 7. Requisitos previos

- Suscripción de Azure activa y permisos suficientes para crear recursos y asignaciones RBAC.
- Azure CLI instalado y autenticado con `az login`.
- Terraform instalado.
- Proveedores de recursos de Azure registrados para los servicios utilizados. Para Azure Container Apps se necesita `Microsoft.App`; para Azure SQL y otros recursos deben estar registrados sus proveedores correspondientes.
- Docker instalado para construir imágenes localmente o en el agente Jenkins.
- Cuenta y repositorio Docker Hub con permisos de publicación.
- Jenkins operativo, con un agente que tenga Git y Docker disponibles.
- Acceso al repositorio Java de GitHub.

El proveedor AzureRM del proyecto establece `resource_provider_registrations = "none"`; por tanto, el registro de proveedores de Azure debe comprobarse y realizarse previamente.

## 8. Configuración segura de variables

Los valores de ejemplo están en `terraform.tfvars`. La contraseña del administrador SQL se define como variable sensible y debe suministrarse mediante una variable de entorno de Terraform, por ejemplo en PowerShell:

```powershell
$env:TF_VAR_sql_admin_password = "<contraseña-fuerte>"
terraform init
terraform validate
terraform plan
terraform apply

# Retirar la variable de la sesión al terminar
Remove-Item Env:TF_VAR_sql_admin_password
```

En Linux:

```bash
export TF_VAR_sql_admin_password='<contraseña-fuerte>'
terraform init
terraform validate
terraform plan
terraform apply
unset TF_VAR_sql_admin_password
```

No guardes contraseñas, tokens, claves SSH ni credenciales de Docker Hub en Git, `terraform.tfvars`, el Jenkinsfile o el README.

Aunque una variable se marque como `sensitive`, su valor puede quedar almacenado en el archivo de estado de Terraform. Usa un backend remoto protegido, cifrado y con control de acceso; restringe también el acceso a los planes y respaldos del state.

## 9. Despliegue de infraestructura

Desde la raíz del repositorio:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Para revisar la IP pública expuesta por el módulo:

```bash
terraform output -raw public_ip_address
```

Para consultar el estado de registro de Microsoft.App:

```bash
az provider show --namespace Microsoft.App --query registrationState -o tsv
```

Si no está registrado, solicita el registro:

```bash
az provider register --namespace Microsoft.App
```

Comprueba que el estado llegue a `Registered` antes de volver a aplicar Terraform. Repite la verificación para cualquier otro proveedor requerido por los recursos del proyecto.

## 10. Consideraciones de seguridad y operación

Antes de utilizar esta configuración fuera de un entorno de laboratorio o desarrollo, revisa al menos lo siguiente:

- **Estado Terraform:** los archivos `terraform.tfstate` y `terraform.tfstate.backup` están presentes en el repositorio. El estado puede contener contraseñas, identificadores y otros datos sensibles. Deben retirarse del control de versiones y migrarse a un backend remoto protegido. Añadirlos al `.gitignore` no elimina las copias ya versionadas.
- **Variables de entorno:** `terraform.tfvars` también está versionado. Verifica que no contenga secretos reales y conserva únicamente valores no sensibles o ejemplos.
- **Key Vault:** la protección contra purga está deshabilitada y el acceso de red pública está habilitado. Evalúa habilitar protección contra purga y restringir la conectividad.
- **Azure SQL:** la regla `AllowAzureServices` no limita el acceso a una sola aplicación. Para un aislamiento mayor, considera VNet, Private Endpoint y reglas de red más restrictivas.
- **Network Security Group:** SSH y los puertos de aplicación aparecen abiertos desde cualquier dirección (`*`). Restringe los orígenes a rangos confiables y elimina puertos que no sean necesarios.
- **Jenkins y Docker:** protege las credenciales y el acceso al socket Docker. Usa credenciales administradas por Jenkins y evita secretos en los logs.
- **Despliegue de imagen:** la consulta de Docker Hub selecciona la etiqueta más recientemente actualizada. Para despliegues reproducibles, considera fijar una etiqueta inmutable o digest de imagen.
- **SQL:** el usuario `appreader` tiene permisos de lectura. No uses una cuenta de administrador para la conexión de la aplicación.

## 11. Limpieza de recursos

Cuando ya no se necesite el entorno, revisa primero el impacto y los recursos asociados. Si Terraform administra el conjunto completo:

```bash
terraform plan -destroy
terraform destroy
```

La destrucción de recursos de Azure puede eliminar datos y generar interrupciones. Realiza respaldos de la base de datos y conserva cualquier información necesaria antes de confirmar.

## 12. Documentación adicional

- [Configuración de Azure SQL](Azure-SQL.md)
- [Instalación y operación de Jenkins con Docker](Jenkins-Docker.md)
- [Repositorio de la aplicación Java](https://github.com/Javierfloresr31/projectdevopsjava)

---

**Proyecto de práctica DevOps:** infraestructura como código con Terraform y automatización de construcción y publicación de contenedores mediante Jenkins y Docker.
