output "gcp_service_account_email" {
  description = "Email of the Google Cloud Service Account created for the DAKR operator. Use this to annotate the Kubernetes SA in Helm: iam.gke.io/gcp-service-account"
  value       = local.operator_sa_email
}

output "ksa_annotation_key" {
  description = "The annotation key to use for the Kubernetes Service Account."
  value       = "iam.gke.io/gcp-service-account"
}

output "ksa_annotation_value" {
  description = "The annotation value (GCP SA email) for the Kubernetes Service Account."
  value       = local.operator_sa_email
}

output "gke_workload_identity_pool" {
  description = "The workload identity pool configured for the GKE cluster."
  value       = "${var.gcp_project_id}.svc.id.goog"
}
