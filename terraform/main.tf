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
  location = "East US"
}

# 2. Azure Event Hubs Namespace (Kafka Endpoint) with Cost Guardrails
resource "azurerm_eventhub_namespace" "eh_namespace" {
  name                = "eh-alpha-factory-namespace-dev"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1

  auto_inflate_enabled     = true
  maximum_throughput_units = 2
}

# 3. Kafka Topic for Market Ticks
resource "azurerm_eventhub" "eh_topic" {
  name                = "alpha-factory-market-ticks"
  namespace_name      = azurerm_eventhub_namespace.eh_namespace.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}

# 4. Azure Data Factory for Orchestration
resource "azurerm_data_factory" "adf" {
  name                   = "adf-alpha-factory-dev"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  public_network_enabled = true
  identity {
    type = "SystemAssigned"
  }
}

# --- ADDED: Client Config & User Role Assignment for ADF Studio Access ---
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "user_df_contributor" {
  scope                = azurerm_data_factory.adf.id
  role_definition_name = "Data Factory Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}
# -------------------------------------------------------------------------

# 5. Look up your EXISTING Databricks workspace (No new workspace is created)
data "azurerm_databricks_workspace" "existing_dbw" {
  name                = "azure_db_ws"   # <-- CHANGE TO YOUR EXISTING WORKSPACE NAME
  resource_group_name = "rg-databricks" # <-- CHANGE TO ITS RESOURCE GROUP
}

# 6. Custom ADF Linked Service for Azure Databricks (Managed Identity Auth)
resource "azurerm_data_factory_linked_custom_service" "databricks_custom" {
  name            = "ls-databricks-rest-api"
  data_factory_id = azurerm_data_factory.adf.id
  type            = "AzureDatabricks"

  type_properties_json = jsonencode({
    domain              = "https://${data.azurerm_databricks_workspace.existing_dbw.workspace_url}"
    authentication      = "ManagedIdentity"
    workspaceResourceId = data.azurerm_databricks_workspace.existing_dbw.id
  })
}

# 7. ADF Pipeline Triggering Databricks Serverless Job via Web Activity (Pattern B)
resource "azurerm_data_factory_pipeline" "alpha_factory_orchestrator" {
  name            = "pl-alpha-factory-end-to-end"
  data_factory_id = azurerm_data_factory.adf.id

  parameters = {
    databricks_job_id = "938869195869371" # Replace with your actual Databricks Serverless Job ID later
  }

  activities_json = jsonencode([
    {
      name      = "TriggerDatabricksServerlessWorkflow",
      type      = "WebActivity",
      dependsOn = [],
      policy = {
        timeout                = "0.12:00:00",
        retry                  = 1,
        retryIntervalInSeconds = 30,
        secureOutput           = false,
        secureInput            = false
      },
      userProperties = [],
      typeProperties = {
        url    = "https://${data.azurerm_databricks_workspace.existing_dbw.workspace_url}/api/2.1/jobs/run-now"
        method = "POST"
        linkedServiceName = {
          referenceName = azurerm_data_factory_linked_custom_service.databricks_custom.name
          type          = "LinkedServiceReference"
        }
        body = {
          job_id = "@pipeline().parameters.databricks_job_id"
        }
        authentication = {
          type     = "MSI"
          resource = "2ff81477-0137-46c0-b540-6322d3a9101d"
        }
      }
    }
  ])
}

# Outputs
output "eventhub_connection_string" {
  value     = azurerm_eventhub_namespace.eh_namespace.default_primary_connection_string
  sensitive = true
}

output "databricks_workspace_url" {
  value = data.azurerm_databricks_workspace.existing_dbw.workspace_url
}