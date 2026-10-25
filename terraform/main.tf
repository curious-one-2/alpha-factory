terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 1. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-alpha-factory-dev"
  location = "East US" # Or your preferred region
}

# 2. Azure Event Hubs Namespace (Kafka Endpoint) with Cost Guardrails
resource "azurerm_eventhub_namespace" "eh_namespace" {
  name                = "eh-alpha-factory-namespace-dev"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1 # Locked to 1 Throughput Unit for low cost
  
  # Cost control: Prevent infinite auto-scaling cost spikes
  auto_inflate_enabled  = true
  maximum_throughput_units = 2 
}

# 3. Kafka Topic for Market Ticks
resource "azurerm_eventhub" "eh_topic" {
  name                = "alpha-factory-market-ticks"
  namespace_name      = azurerm_eventhub_namespace.eh_namespace.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2 # Low partition count saves resource overhead for dev/testing
  message_retention   = 1 # Retain messages for 1 day max to save storage costs
}

# 4. Azure Data Factory for Orchestration
resource "azurerm_data_factory" "adf" {
  name                = "adf-alpha-factory-dev"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  public_network_enabled = true
}