variable "azure_location" {
  description = "The Azure region where the AKS cluster and Identity resources are located."
  type        = string
}

variable "aks_cluster_name" {
  description = "The name of your existing AKS cluster."
  type        = string
}

variable "aks_cluster_resource_group_name" {
  description = "The name of the resource group where the AKS cluster is located."
  type        = string
}

variable "subscription_id" {
  description = "The Azure Subscription ID where the resources are located."
  type        = string
}

variable "operator_service_account_name" {
  description = "The name of the Kubernetes ServiceAccount that Helm will create. This must match the SA name in your Helm chart's values."
  type        = string
  default     = "dakr-operator-sa"
}

variable "operator_namespace" {
  description = "The Kubernetes namespace where the operator and its ServiceAccount will be deployed by Helm."
  type        = string
  default     = "devzero"
}

variable "tags" {
  description = "A map of tags to assign to the Azure resources."
  type        = map(string)
  default = {
    "ManagedBy" = "Terraform"
    "Project"   = "devzero-dakr"
  }
}
