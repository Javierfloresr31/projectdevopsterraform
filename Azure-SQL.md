# Azure SQL para la aplicación Java

Terraform crea un servidor Azure SQL y una base `Basic` de 2 GB en Central US, dentro del mismo resource group que Container Apps. El servidor permite conexiones públicas desde servicios de Azure porque el entorno actual de Container Apps no tiene integración VNet ni una IP de salida fija. La Container App permanece en West US 2, por lo que la conexión cruza regiones.

## Crear los recursos

No guardes la contraseña del administrador en `terraform.tfvars` ni en el repositorio. Antes de aplicar, prepara un backend remoto protegido para el state. Después, proporciona la contraseña en el entorno de la sesión:

```powershell
$env:TF_VAR_sql_admin_password = "<contraseña-fuerte>"
terraform init
terraform plan
terraform apply
Remove-Item Env:TF_VAR_sql_admin_password
```

La contraseña es sensible, pero Terraform la guarda en el state. Restringe el acceso al backend y habilita su cifrado.

El nombre DNS del servidor SQL debe ser único globalmente. Si el nombre predeterminado ya está ocupado, cámbialo con `-var="sql_server_name=..."` y actualiza `azure.sql.server` en `projectdevopsjava/src/main/resources/application.properties`. Si Azure también bloquea el aprovisionamiento en Central US, solicita a Azure Support que revise las restricciones de la suscripción.

## Crear el usuario de la aplicación

Conéctate a la base como administrador y ejecuta `sql/create_app_user.sql`, sustituyendo el marcador por una contraseña fuerte. El script crea `dbo.Users` si todavía no existe, con las columnas `Id` (identity), `Name` y `Email`; agrega tres filas ficticias de ejemplo sin duplicarlas al volver a ejecutarlo; y crea el usuario `appreader` con permiso de lectura. Guarda el usuario y la contraseña en Key Vault como `sql-app-user` y `sql-app-password`; no los incluyas en archivos del proyecto.

En la Container App configura `USER` y `PASSWORD` como referencias a esos secretos de Key Vault. La identidad asignada de la Container App ya tiene permiso de lectura sobre `kv_01`.

La aplicación ejecuta `SELECT * FROM dbo.Users`; el script prepara esa tabla antes de habilitar el acceso de la aplicación.

## Red y costo

La regla `AllowAzureServices` permite el acceso desde recursos Azure y no restringe el tráfico a esta Container App únicamente. Requiere autenticación SQL y debe considerarse una configuración sencilla para desarrollo; para mayor aislamiento, integra Container Apps con una VNet y usa Private Endpoint.

El nivel Basic tiene costo recurrente aunque la aplicación no esté en uso.
