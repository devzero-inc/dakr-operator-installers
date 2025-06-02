variable "aws_region" {
  description = "The AWS region where the EKS cluster and IAM resources will be managed."
  type        = string
}

variable "eks_cluster_name" {
  description = "The name of your existing EKS cluster."
  type        = string
}

variable "operator_service_account_name" {
  description = "The static name of the Kubernetes ServiceAccount that Helm will create (e.g., 'dakr-operator-sa'). This must match the SA name in your Helm chart's values."
  type        = string
  default     = "dakr-operator-sa"
}

variable "operator_namespace" {
  description = "The Kubernetes namespace where the operator and its ServiceAccount will be deployed by Helm. This is used in the IAM role's trust policy and must match Helm's deployment namespace."
  type        = string
  default     = "devzero"
}

variable "tags" {
  description = "A map of tags to assign to the AWS resources."
  type        = map(string)
  default = {
    "ManagedBy" = "Terraform"
    "Project"   = "devzero-dakr"
  }
}
