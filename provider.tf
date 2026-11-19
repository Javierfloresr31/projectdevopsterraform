terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "=3.5.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  resource_provider_registrations = "none"
  features {}
  subscription_id = "2cdf87b8-355b-46ef-94ed-5bda223e5d39"
}