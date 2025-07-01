provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

data "google_container_cluster" "cluster" {
  name     = var.gke_cluster_name
  location = var.gcp_region // Assumes region is used for location. Adjust if cluster is zonal.
  project  = var.gcp_project_id
}

// The DAKR operator requires Workload Identity to be enabled on the GKE cluster.
// This Terraform module assumes Workload Identity has ALREADY been enabled manually.
// See the README.md for instructions on how to enable it using 'gcloud'.

data "google_service_account" "existing_operator_sa" {
  account_id = var.operator_service_account_name_gcp
  project    = var.gcp_project_id
}

resource "google_service_account" "operator_sa" {
  count        = data.google_service_account.existing_operator_sa == null ? 1 : 0
  account_id   = var.operator_service_account_name_gcp
  display_name = "DAKR Operator GCP Service Account"
  project      = var.gcp_project_id
}

locals {
  operator_sa_email = coalesce(
    try(google_service_account.operator_sa[0].email, null),
    try(data.google_service_account.existing_operator_sa.email, null)
  )
  operator_sa_name = coalesce(
    try(google_service_account.operator_sa[0].name, null),
    try(data.google_service_account.existing_operator_sa.name, null)
  )
}

// Bind KSA to GSA for Workload Identity
resource "google_service_account_iam_member" "operator_ksa_impersonate_gsa" {
  service_account_id = local.operator_sa_name // This is the unique ID: projects/{project}/serviceAccounts/{email}
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.operator_namespace}/${var.operator_service_account_name}]"
  // Workload Identity must be enabled on the cluster for this binding to be effective.
  // This is now a manual prerequisite step for the user (see README.md).
}

// Grant GSA required roles on the project
resource "google_project_iam_member" "operator_gsa_compute_viewer" {
  project = var.gcp_project_id
  role    = "roles/compute.viewer" // For compute.instances.get
  member  = "serviceAccount:${local.operator_sa_email}"
}

resource "google_project_iam_member" "operator_gsa_container_viewer" {
  project = var.gcp_project_id
  role    = "roles/container.viewer" // For container.nodePools.get
  member  = "serviceAccount:${local.operator_sa_email}"
}

resource "google_project_iam_member" "operator_gsa_compute_instance_admin" {
  project = var.gcp_project_id
  role    = "roles/compute.instanceAdmin.v1" // For compute.instances.delete, compute.*InstanceGroupManagers.deleteInstances
  member  = "serviceAccount:${local.operator_sa_email}"
}
