# Dynamic Adjustment of Kubernetes Resources Operator (DAKR)

# DAKR Operator setup

This guide outlines the steps to configure the necessary cloud provider IAM permissions for the DAKR operator to run on AWS EKS or GCP GKE and install the dakr operator.

## Prerequisites

*   Relevant Cloud CLI configured (AWS CLI or `gcloud` CLI).
*   Terraform CLI installed.
*   Helm CLI installed.
*   `kubectl` configured to interact with your Kubernetes cluster.

## Setup Steps

The process involves two main parts:
1.  **Configure Cloud IAM (Terraform):** Run the Terraform module for your chosen cloud provider (AWS or GCP) to set up IAM roles/service accounts and permissions.
2.  **Deploy DAKR Operator (Helm):** Update `helm/dakr/values.yaml` with the Terraform outputs and deploy the operator.

---

### 1. Configure Cloud IAM (Terraform)

Choose the instructions for your cloud provider:

#### Option A: AWS EKS

The Terraform configuration for AWS is in `terraform/aws/`.

a.  **Navigate to the AWS Terraform directory:**

    cd terraform/aws

b.  **Initialize Terraform:**

    terraform init

c.  **Apply Terraform changes:**
    Replace placeholders with your AWS-specific values.

    terraform apply \
      -var="aws_region=YOUR_AWS_REGION" \
      -var="eks_cluster_name=YOUR_EKS_CLUSTER_NAME" \
      -var="operator_namespace=YOUR_OPERATOR_NAMESPACE"

  *   The `operator_service_account_name` defaults to `dakr-operator-sa` (this should match the `name` under `operator.serviceAccount` in `helm/dakr/values.yaml`).
  *   Ensure your EKS cluster has an OIDC provider enabled; the Terraform script will attempt to create it if not found.

d.  **Note Terraform Outputs for Helm:**
    After a successful apply, Terraform will output:
  *   `ksa_annotation_key_aws`: The annotation key (e.g., `eks.amazonaws.com/role-arn`).
  *   `operator_iam_role_arn`: The annotation value (the ARN of the created IAM role).

#### Option B: GCP GKE

**0. Enable Workload Identity on GKE Cluster (Manual Step)**

Before running Terraform for GCP, you must enable Workload Identity on your GKE cluster if it's not already active. Use the following `gcloud` command, replacing `CLUSTER_NAME`, `LOCATION` (e.g., `us-central1` or `us-central1-a`), and `PROJECT_ID` with your specific values:

```bash
gcloud container clusters update CLUSTER_NAME \
    --location=LOCATION \
    --workload-pool=PROJECT_ID.svc.id.goog
```

This step enables Workload Identity for the cluster. It may take a minute, please be patient.

Next, configure each node pool to use the GKE metadata server. Replace `NODEPOOL_NAME`, `CLUSTER_NAME`, and `LOCATION` (control plane location) with your values:
```bash
gcloud container node-pools update NODEPOOL_NAME \
    --cluster=CLUSTER_NAME \
    --location=LOCATION \
    --workload-metadata=GKE_METADATA
```
This ensures pods on this node pool can use Workload Identity. Which is needed for the Dakr operator to authenticate to GCP APIs. Repeat for all relevant node pools. This operation may cause nodes to be recreated!

**1. Configure GCP IAM (Terraform)**

The Terraform configuration for GCP is in `terraform/gcp/`.

a.  **Navigate to the GCP Terraform directory:**

    cd terraform/gcp

b.  **Initialize Terraform:**

    terraform init

c.  **Apply Terraform changes:**
    Replace placeholders with your GCP-specific values.

    terraform apply \
      -var="gcp_project_id=YOUR_GCP_PROJECT_ID" \
      -var="gcp_region=YOUR_GCP_REGION_OR_ZONE" \
      -var="gke_cluster_name=YOUR_GKE_CLUSTER_NAME" \
      -var="operator_namespace=YOUR_OPERATOR_NAMESPACE"

  *   The Kubernetes Service Account name (`operator_service_account_name`) defaults to `dakr-operator-sa` (this should match the `name` under `operator.serviceAccount` in `helm/dakr/values.yaml`).
  *   The Google Cloud Service Account ID (`operator_service_account_name_gcp`) defaults to `dakr-operator-gcp-sa`.
  *   Workload Identity (enabled in step 0) is a prerequisite for the IAM bindings in this Terraform module to function correctly.

d.  **Note Terraform Outputs for Helm:**
    After a successful apply, Terraform will output:
  *   `ksa_annotation_key`: The annotation key (e.g., `iam.gke.io/gcp-service-account`).
  *   `gcp_service_account_email`: The annotation value (the email of the created Google Cloud Service Account).

---

### 2. Deploy DAKR Operator (Helm)

After completing the Terraform setup for your chosen cloud provider:

a.  **Update Helm Values:**
    Edit `helm/dakr/values.yaml`. Locate the `operator.serviceAccount.annotations` section.
    Replace the placeholder key and value with the specific outputs noted from your Terraform apply (AWS or GCP).

  **Example structure in `values.yaml`:**

    # helm/dakr/values.yaml
    # ...
    operator:
      serviceAccount:
        name: "dakr-operator-sa" # Ensure this matches the SA name used/expected by Terraform
        # Annotations for cloud provider IAM integration.
        # Replace the placeholder key-value pair below with the
        # 'ksa_annotation_key*' and corresponding value output
        # from your cloud-specific Terraform module.
        #
        # For AWS, it would be:
        #   "eks.amazonaws.com/role-arn": "ARN_FROM_TERRAFORM_OUTPUT"
        # For GCP, it would be:
        #   "iam.gke.io/gcp-service-account": "GSA_EMAIL_FROM_TERRAFORM_OUTPUT"
        annotations:
          "placeholder.terraform.output/annotation-key": "placeholder-terraform-output-annotation-value"
    # ...

  Ensure the `operator.serviceAccount.name` in `values.yaml` matches the service account name targeted by your Terraform configuration (default is `dakr-operator-sa`).

b.  **Deploy/Upgrade with Helm:**
    Replace `<release-name>` with your desired Helm release name.
    Replace `YOUR_OPERATOR_NAMESPACE` with the namespace where the operator should be deployed (this must match the `operator_namespace` used in Terraform).
    
    helm upgrade --install <release-name> ./helm/dakr \
      --namespace YOUR_OPERATOR_NAMESPACE \
      --create-namespace

  The `--create-namespace` flag will create the namespace if it doesn't exist.

Your DAKR operator should now be deployed with the necessary cloud IAM permissions.

---

## Debugging: Manual Node Deletion API

The DAKR operator exposes an HTTP endpoint for manually triggering node deletion for debugging purposes. This endpoint is served on the port defined by `operator.debugPort` in `helm/dakr/values.yaml` (defaults to `8082`).

**Steps:**

1.  **Port-forward to the operator pod:**
    Replace `<operator-pod-name>` and `<operator-namespace>` with your specific values.
    ```bash
    kubectl port-forward <operator-pod-name> -n <operator-namespace> 8082:8082
    ```
    (If you configured a different `operator.debugPort` in your Helm values, use that port number in the command above and in the `curl` command below.)

2.  **Send the POST request:**
    In a new terminal, use `curl` to send a POST request to the `/delete-node/{nodeName}` endpoint. Replace `{nodeName}` with the actual name of the Kubernetes node you want to delete.
    ```bash
    curl -X POST http://localhost:8082/delete-node/{nodeName}
    ```
    For example, to delete a node named `ip-10-0-1-123.ec2.internal` (AWS) or `gke-my-cluster-default-pool-xxxx` (GCP):
    ```bash
    curl -X POST http://localhost:8082/delete-node/your-node-name-here
    ```
    A successful request will return an HTTP 200 status and a message indicating that the node deletion was initiated. Check the operator logs for more details on the deletion process.

**Caution:** This endpoint is intended for debugging and manual intervention. Exercise caution when using it, as it directly triggers node deletion.
