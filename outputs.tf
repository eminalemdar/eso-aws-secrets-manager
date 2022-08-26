################################################################################
# Cluster Data
################################################################################

output "cluster_id" {
  description = "eks_cluster cluster ID."
  value       = module.eks_cluster.eks_cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for eks_cluster control plane."
  value       = module.eks_cluster.eks_cluster_endpoint
}

output "kms_key_arn" {
  description = "ARN of the KMS Key"
  value       = aws_kms_key.secrets.arn
}

output "secrets_manager_arn" {
  description = "ARN of the Secrets Manager"
  value       = aws_secretsmanager_secret.secret.arn
}