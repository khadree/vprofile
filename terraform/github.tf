resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"
  tags = { Purpose = "GitHub Actions CI/CD" }
}

resource "aws_iam_user_policy" "github_actions_ecr" {
  name = "${var.project_name}-ecr-push-policy"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allows docker login to ECR (must be * — no resource-level restriction)
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # Push/pull scoped to THIS repo only
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = module.ecs.ecr_repo_arn
      },
      {
        # Allows GitHub Actions to trigger a new ECS deployment after image push
        Sid    = "ECSUpdate"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = module.ecs.ecs_service_id
      }
    ]
  })
}

# Programmatic access keys for the IAM user
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}



resource "github_actions_secret" "aws_access_key_id" {
  repository = var.github_repo
  secret_name = "AWS_ACCESS_KEY_ID"
  value      = aws_iam_access_key.github_actions.id   
}

resource "github_actions_secret" "aws_secret_access_key" {
  repository  = var.github_repo
  secret_name = "AWS_SECRET_ACCESS_KEY"
  value       = aws_iam_access_key.github_actions.secret  
}

resource "github_actions_secret" "ecr_repo_name" {
  repository  = var.github_repo
  secret_name = "ECR_REPO_NAME"
  value       = module.ecs.ecr_repo_name  
}

resource "github_actions_secret" "sonar_token" {
  repository  = var.github_repo
  secret_name = "SONAR_TOKEN"
  value       = var.sonar_token   
}

resource "github_actions_secret" "sonar_project_key" {
  repository  = var.github_repo
  secret_name = "SONAR_PROJECT_KEY"
  value       = var.sonar_project_key   
}

resource "github_actions_secret" "sonar_org" {
  repository  = var.github_repo
  secret_name = "SONAR_ORG"
  value       = var.sonar_org  
}


resource "github_actions_secret" "ecs_service_name" {
  repository  = var.github_repo
  secret_name = "ECS_SERVICE_NAME"
  value       = module.ecs.ecs_service_name  
}

resource "github_actions_secret" "ecs_cluster_name" {
  repository  = var.github_repo
  secret_name = "ECS_CLUSTER_NAME"
  value       = module.ecs.ecs_cluster_name  
}