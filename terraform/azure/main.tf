provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_cluster_resource_group_name
}

resource "azurerm_user_assigned_identity" "operator_identity" {
  name                = "${var.aks_cluster_name}-operator-identity"
  resource_group_name = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  location            = data.azurerm_kubernetes_cluster.cluster.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "operator_role_assignment" {
  scope              = data.azurerm_kubernetes_cluster.cluster.id
# see https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/containers#azure-kubernetes-service-contributor-role 
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ed7f3fbd-7b88-4dd4-9017-9adb7ce333f8" 
  principal_id       = azurerm_user_assigned_identity.operator_identity.principal_id
}

resource "azurerm_federated_identity_credential" "operator_fic" {
  name                = "${var.aks_cluster_name}-operator-fic"
  resource_group_name = data.azurerm_kubernetes_cluster.cluster.node_resource_group
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.cluster.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.operator_identity.id
  subject             = "system:serviceaccount:${var.operator_namespace}:${var.operator_service_account_name}"
}
