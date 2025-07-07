output "operator_identity_client_id" {
  description = "The Client ID of the User-Assigned Managed Identity for the DAKR operator. This is used in the ServiceAccount annotation."
  value       = azurerm_user_assigned_identity.operator_identity.client_id
}

output "ksa_annotation_key_client_id" {
  description = "The annotation key for the Kubernetes Service Account on Azure AKS for the client ID."
  value       = "azure.workload.identity/client-id"
}
