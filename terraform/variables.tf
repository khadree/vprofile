variable "project_name" {
  description = "Project name"
  type        = string
}
variable "region" {
  description = "AWS region"
  type        = string
}
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}


variable "s3_bucket" {
  description = "Map of S3 bucket to create (keyed by instance id/name)."
  type        = map(any)
  default = {
  }
}

variable "alb" {
  description = "Map of ALB configurations"
  type        = map(any)
  default = {
    # "primary" = {} # This creates one instance keyed as "primary"
  }
}

variable "versioning_enabled" {
  description = "Whether versioning is enabled for the S3 bucket"
  type        = string
  default     = "Enabled"
}

variable "github_token" {
  description = "GitHub Personal Access Token with repo + secrets permissions"
  type        = string
  sensitive   = true
}



variable "github_repo" {
  description = "GitHub repo in owner/name format"
  type        = string
}

variable "sonar_token" {
  description = "SonarCloud token from sonarcloud.io → My Account → Security"
  type        = string
  sensitive   = true
}

variable "sonar_project_key" {
  description = "SonarCloud project key e.g. johndoe_vprofile"
  type        = string
}

variable "sonar_org" {
  description = "SonarCloud organisation slug (your GitHub username in lowercase)"
  type        = string
}