provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

locals {
  eks_oidc_issuer_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "tls_certificate" "eks_oidc_thumbprint" {
  url = local.eks_oidc_issuer_url
}

# Get existing OIDC provider for the EKS cluster
data "aws_iam_openid_connect_provider" "existing_eks_oidc_provider" {
  url = local.eks_oidc_issuer_url
}

locals {
  # Extract the OIDC issuer ID from the URL (part after the last slash)
  oidc_issuer_id = split("/", local.eks_oidc_issuer_url)[length(split("/", local.eks_oidc_issuer_url)) - 1]
  
  # Find existing OIDC provider ARN that matches our EKS cluster's OIDC issuer
  existing_oidc_provider_arn = try(data.aws_iam_openid_connect_provider.existing_eks_oidc_provider.arn, null)
  
  # Determine if we need to create a new OIDC provider
  should_create_oidc_provider = local.existing_oidc_provider_arn == null
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  count           = local.should_create_oidc_provider ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = local.eks_oidc_issuer_url

  tags = var.tags
}

locals {
  effective_eks_oidc_provider_arn    = local.should_create_oidc_provider ? aws_iam_openid_connect_provider.eks_oidc_provider[0].arn : local.existing_oidc_provider_arn
  oidc_issuer_hostpath_for_condition = replace(local.eks_oidc_issuer_url, "https://", "")
}

resource "aws_iam_policy" "operator_policy" {
  name        = "${var.eks_cluster_name}-${var.operator_service_account_name}-policy"
  description = "IAM policy for DAKR operator SA ${var.operator_service_account_name} on EKS cluster ${var.eks_cluster_name}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ec2:DescribeInstances"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["eks:DescribeCluster"],
        Resource = data.aws_eks_cluster.cluster.arn
      },
      {
        Effect   = "Allow",
        Action   = ["ec2:TerminateInstances"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["autoscaling:TerminateInstanceInAutoScalingGroup"],
        Resource = "*"
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role" "operator_role" {
  name                 = "${var.eks_cluster_name}-${var.operator_service_account_name}-role"
  description          = "IAM role for DAKR operator SA ${var.operator_service_account_name} in ${var.operator_namespace}"
  assume_role_policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = local.effective_eks_oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_hostpath_for_condition}:sub" = "system:serviceaccount:${var.operator_namespace}:${var.operator_service_account_name}"
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "operator_attach" {
  role       = aws_iam_role.operator_role.name
  policy_arn = aws_iam_policy.operator_policy.arn
}
