location = "westus 2"
sql_location = "centralus"
tags = {
  Environment = "Desarrollo"
  Department  = "TI"
  Clase       = "DMC"
}
// RESOURCE GROUP 01------------------------------- 
rg_01_name = "rg-project-dev-westus2-001"

// Environments(cae)
cae_01_name             = "cae-project-dev-westus2-001"
cae_01_workload_profile = "Consumption"

// Container Apps(ca)
aca_01_name = "ca-project-dev-westus2-001"

//identity 

identity_01_name = "id-project-dev-westus2-001"

//Keyvault

kv_01_name             = "kvjavierfr3devwestus2001"
kv_02_name             = "kvjavierfr3devwestus2002"
kv_03_name             = "kvjavierfr3devwestus2003"
kv_04_name             = "kvjavierfr3devwestus2004"
kv_pep_aca_01_name     = "pep-project-dev-westus2-001"
kv_pep_aca_01_name_nic = "pep-project-dev-westus2-001-nic"


