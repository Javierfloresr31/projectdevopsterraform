variable "location" {
  description = "La ubicación donde se creará el componente"
  type        = string
}

variable "tags" {
  description = "Etiquetas opcionales para aplicar al componente"
  type        = map(string)
  default = {
    Environment = ""
  }
}

// RESOURCE GROUP 01------------------------------- 
variable "rg_01_name" {
  description = "El nombre del grupo de recursos 1"
  type        = string
}

// Container Apps(ca) & Environments(cae) 01

variable "cae_01_workload_profile" {
  description = "El Workload del cae 01"
  type        = string
}

variable "cae_01_name" {
  description = "El nombre del cae 01"
  type        = string
}

variable "aca_01_name" {
  description = "El nombre del aca 01"
  type        = string
}

variable "aca_01_image" {
  description = "El repositorio Docker Hub del Container App, sin etiqueta"
  type        = string
  default     = "docker.io/javierfloresr31/myapp"
}

variable "sql_server_name" {
  description = "Nombre DNS global del servidor Azure SQL"
  type        = string
  default     = "sql-terraformcloud-dev-centralus-001"
}

variable "sql_database_name" {
  description = "Nombre de la base de datos Azure SQL"
  type        = string
  default     = "sqldb-terraformcloud-dev-centralus-001"
}

variable "sql_location" {
  description = "Región del servidor Azure SQL, independiente de la región del resource group"
  type        = string
  default     = "centralus"
}

variable "sql_admin_username" {
  description = "Usuario administrador del servidor Azure SQL"
  type        = string
  default     = "sqlterraformadmin"
}

variable "sql_admin_password" {
  description = "Contraseña del administrador SQL; no guardar en terraform.tfvars"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.sql_admin_password) >= 8 &&
      length(var.sql_admin_password) <= 128 &&
      (
        (length(regexall("[A-Z]", var.sql_admin_password)) > 0 ? 1 : 0) +
        (length(regexall("[a-z]", var.sql_admin_password)) > 0 ? 1 : 0) +
        (length(regexall("[0-9]", var.sql_admin_password)) > 0 ? 1 : 0) +
        (length(regexall("[^A-Za-z0-9]", var.sql_admin_password)) > 0 ? 1 : 0)
      ) >= 3
    )
    error_message = "La contraseña debe tener entre 8 y 128 caracteres e incluir al menos tres de estos grupos: mayúsculas, minúsculas, números y símbolos."
  }
}

// identity
variable "identity_01_name" {
  description = "El nombre del identity 01"
  type        = string
}

// KeyVault

variable "kv_01_name" {
  description = "El nombre del keyvault 01"
  type        = string
}

variable "kv_02_name" {
  description = "El nombre del keyvault 02"
  type        = string
}

variable "kv_03_name" {
  description = "El nombre del keyvault 03"
  type        = string
}

variable "kv_04_name" {
  description = "El nombre del keyvault 04"
  type        = string
}

variable "kv_pep_aca_01_name" {
  description = "El nombre del privante endpoint 01"
  type        = string
}

variable "kv_pep_aca_01_name_nic" {
  description = "el nombre de la nic de la privante endpoint 01"
  type        = string
}

// Storage Account 01
variable "st_01_name" {
  description = "Nombre del storage account"
  type        = string
}

//Azure Files 01

variable "share_01_name" {
  description = "Nombre del Azure Files"
  type        = string
}
