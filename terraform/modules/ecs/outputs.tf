output "ecr_repository_url" {
  description = "Full ECR URL — also available in GitHub as secret ECR_REPO_NAME"
  value       = aws_ecr_repository.image_repo.repository_url
}

output "ecr_repo_name" {
  value = aws_ecr_repository.image_repo.name
}
output "ecr_repo_arn" {
  value = aws_ecr_repository.image_repo.arn
}
output "ecs_service_id" {
  value = aws_ecs_service.app_service.id
}

output "ecs_service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}