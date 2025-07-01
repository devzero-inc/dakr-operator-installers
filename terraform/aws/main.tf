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

data "external" "existing_eks_oidc_provider" {
  program = ["bash", "${path.module}/check_oidc.sh"]
  query = {
    url = local.eks_oidc_issuer_url
  }
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  count           = data.external.existing_eks_oidc_provider.result.arn == "" ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = local.eks_oidc_issuer_url

  tags = var.tags
}

locals {
  effective_eks_oidc_provider_arn    = coalesce(aws_iam_openid_connect_provider.eks_oidc_provider[0].arn, data.external.existing_eks_oidc_provider.result.arn)
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
        Action   = ["eks:DescribeNodegroup"],
        Resource = "*"
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
      },
      {
        Effect   = "Allow",
        Action   = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity"
        ],
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
