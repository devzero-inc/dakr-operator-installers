variable "gcp_project_id" {
  description = "The GCP project ID where the GKE cluster and IAM resources will be managed."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region where the GKE cluster is located (e.g., 'us-central1'). For zonal clusters, this variable should represent the zone."
  type        = string
}

variable "gke_cluster_name" {
  description = "The name of your existing GKE cluster."
  type        = string
}

variable "operator_service_account_name" {
  description = "The name of the Kubernetes ServiceAccount used by the DAKR operator (e.g., 'dakr-operator-sa'). This must match the SA name in your Helm chart."
  type        = string
  default     = "dakr-operator-sa"
}

variable "operator_service_account_name_gcp" {
  description = "The account_id for the Google Cloud Service Account to be created (e.g., 'dakr-operator-gcp-sa'). This should be unique within the GCP project."
  type        = string
  default     = "dakr-operator-gcp-sa"
}

variable "operator_namespace" {
  description = "The Kubernetes namespace where the DAKR operator and its ServiceAccount are deployed."
  type        = string
  default     = "devzero"
}

variable "labels" {
  description = "A map of labels to assign to the GCP resources."
  type        = map(string)
  default = {
    "managed-by" = "terraform"
    "project"    = "devzero-dakr"
  }
}
