output "operator_iam_role_arn" {
  description = "ARN of the IAM role created for the DAKR operator. This is the value for the ServiceAccount annotation."
  value       = aws_iam_role.operator_role.arn
}

output "ksa_annotation_key_aws" {
  description = "The annotation key to use for the Kubernetes Service Account on AWS EKS."
  value       = "eks.amazonaws.com/role-arn"
}

