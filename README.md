# Vprofile — CI/CD on AWS ECS Fargate

A Spring MVC Java web application with a fully automated CI/CD pipeline. Infrastructure is provisioned by Terraform before the pipeline runs. GitHub Actions handles testing, code analysis, artifact publishing, and Docker image delivery to AWS ECR — with zero manual steps.

The terraform code deploy an application to AWS ECS, provisiong the VPC,ECS cluster,ECS service, Container Registry, Target Group, Application load Balancer.

---

## Architecture overview

```
GitHub repo (push to main)
        │
        ▼
GitHub Actions Pipeline
  ├── Job 1: Test & Analyse (runs on every push + PR)
  │     ├── Unit tests          (mvn test)
  │     ├── Integration tests   (mvn verify -DskipUnitTests)
  │     ├── Checkstyle          (mvn checkstyle:checkstyle)
  │     ├── SonarCloud scan     (mvn sonar:sonar)
  │     └── Publish artifact    (GitHub Packages / mvn deploy)
  │
  └── Job 2: Build & Push (main branch only, needs Job 1)
        ├── Build WAR           (mvn package -DskipTests)
        ├── AWS credentials     (injected by Terraform)
        ├── ECR login
        └── Docker build + push (tagged :sha + :latest)

AWS Infrastructure (provisioned by Terraform first)
  ├── VPC          (public + private subnets, NAT gateway)
  ├── Amazon ECR   (image registry, IMMUTABLE tags, lifecycle policy)
  ├── ECS Fargate  (cluster, service, task definition)
  ├── ALB          (Application Load Balancer → target group → ECS)
  ├── S3           (versioned, encrypted, app data)
  └── CloudWatch   (ECS log group, 7-day retention)
```

---
 
 ## System Diagram / CI/CD Architecture diagram

 See the systems/ folder for cici_architecture_diagram.svg and damolak.png for detailed communication flows, interaction general Overview. 

## Repository structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions pipeline
├── src/
│   ├── main/java/             # Application source
│   └── test/java/             # Unit + integration tests
├── terraform/
│   ├── github.tf              # GitHub secrets automation
│   ├── ecs.tf                 # ECS module call
│   ├── alb.tf                 # ALB module call
│   ├── vpc.tf                 # VPC module call
│   ├── s3.tf                  # S3 module call
│   ├── variables.tf
│   ├── version.tf
│   └── modules/
│       ├── ecs/               # ECR, ECS cluster, service, task, IAM
│       ├── alb/               # ALB, target group, listener, SG
│       ├── vpc/               # VPC, subnets, NAT, route tables
│       └── s3/                # S3 bucket, versioning, encryption
├── Dockerfile
└── pom.xml
```

---

## Design decisions

### Single repository for app + infrastructure

Both application code and Terraform live in the same repo. This means every change — whether to the app or the infrastructure — goes through the same review and pipeline process. It also makes it easy to see the relationship between the app's needs and the infrastructure that supports it.

### Terraform provisions everything first, including pipeline secrets

The most important decision in this setup: **Terraform uses the GitHub Terraform provider to push all GitHub Actions secrets automatically after `terraform apply`**. This means:

- The ECR repository URL is never copy-pasted manually
- AWS credentials are generated for a least-privilege IAM user and pushed directly
- SonarCloud tokens are pushed without touching the GitHub UI
- There is no step where a human must configure a secret

This is enforced via `github.tf`, which depends on outputs from the ECS module (`module.ecs.ecr_repo_name`, `module.ecs.ecr_repo_arn`) and creates six secrets in the repository.

### Dedicated IAM user for GitHub Actions (not the ECS execution role)

A separate `aws_iam_user` resource is created specifically for the pipeline. It has exactly three permissions:

1. `ecr:GetAuthorizationToken` — to log in to ECR (must be `*`, AWS does not support resource-level restriction here)
2. ECR push/pull actions — scoped to only the application's ECR repository ARN
3. `ecs:UpdateService` + `ecs:DescribeServices` — scoped to only the application's ECS service

The `ecs_execution_role` is a separate IAM role used by ECS at container runtime to pull images and write logs. It is an AWS-assumed role, not a user with static keys. GitHub Actions cannot assume it without already being inside AWS, so a dedicated IAM user is the correct approach.

### IMMUTABLE ECR image tags

The ECR repository is configured with `image_tag_mutability = "IMMUTABLE"`. This means:

- An image tagged `:abc123` can never be overwritten by a different image with the same tag
- Every deployment is traceable to a specific Git commit SHA
- Rollbacks are reliable — pulling `:abc123` always gives the same image

The pipeline tags every image twice: once with the Git commit SHA (`:${{ github.sha }}`) for traceability, and once with `:latest` for convenience. Because tags are immutable, the `:latest` push replaces the tag only by updating the reference.

### ECR lifecycle policy

A lifecycle policy keeps the last 10 images and expires the rest. Without this, ECR storage grows indefinitely. 10 images provides sufficient rollback history for a small team while keeping costs predictable.

### Two-job pipeline with `needs`

The pipeline splits into two jobs deliberately:

**Job 1** runs on every push and every pull request. It never touches AWS. This means code quality gates run on PRs before merging, without requiring AWS credentials in the PR context.

**Job 2** runs only on push to `main`, and only if Job 1 succeeds (`needs: test-and-analyse`). It requires AWS credentials and pushes the Docker image. This ensures an image is never built from code that failed tests or quality analysis.

### SonarCloud instead of self-hosted SonarQube

SonarCloud is free for public repositories and requires no server to maintain. It provides identical analysis rules, quality gates, and JaCoCo/Checkstyle report integration. The `sonar-maven-plugin` is declared in `pom.xml` so analysis runs as a standard Maven goal with no external tooling.

**Important**: Automatic Analysis must be disabled in the SonarCloud project settings. Running both automatic analysis and `mvn sonar:sonar` simultaneously causes a conflict.

### GitHub Packages instead of Nexus

GitHub Packages provides a Maven-compatible artifact registry with no infrastructure required. Authentication reuses the built-in `GITHUB_TOKEN` (a per-run token automatically provided by GitHub Actions — not a custom secret). The `<distributionManagement>` block in `pom.xml` points to the repository URL.

### JaCoCo for coverage reporting

JaCoCo is configured in `pom.xml` to generate a coverage report during the build. SonarCloud reads the `.exec` file at `target/jacoco.exec` to include coverage data in the quality analysis. The plugin runs in two phases: `prepare-agent` (attaches the JaCoCo agent before tests run) and `report` (generates the report after tests complete).

### ECS Fargate with `desired_count = 0`

The ECS service is initially set to `desired_count = 0`. This means no tasks are running after `terraform apply`, which avoids charges while the first image is being built. Once the pipeline pushes the first image to ECR, uncomment the ECS update step in the workflow to trigger a deployment, then increase `desired_count` to 1 or more in Terraform.

### Private subnets for ECS tasks

ECS tasks run in private subnets and communicate with the internet through a NAT gateway. The ALB sits in public subnets and forwards traffic to the ECS tasks. This means:

- Application containers are never directly reachable from the internet
- Outbound traffic from containers (pulling dependencies, calling external APIs) goes through the NAT gateway
- Only the ALB has a public IP

### CloudWatch log retention at 7 days

Logs are retained for 7 days to keep CloudWatch storage costs low during development. Increase this value in `modules/ecs/main.tf` for production workloads where longer audit trails are required.

---

## Prerequisites

- AWS account with programmatic access
- Terraform >= 1.5
- GitHub account with a Personal Access Token (scopes: `repo`, `write:packages`, `admin:repo_hook`)
- SonarCloud account (free at sonarcloud.io — sign in with GitHub, import the repo)

---

## Setup

### 1. Clone and configure variables

```bash
git clone https://github.com/khadree/damolak.git
cd /terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_name      = "your-project-name"
region            = "eu-west-1"
github_token      = "github_pat_..."
github_repo       = "your-repo-name"          # just the name, not owner/name
sonar_token       = "your-sonarcloud-token"
sonar_project_key = "your-org_your-repo"
sonar_org         = "your-github-username"
```

### 2. Add pom.xml distribution management

In `pom.xml`, update the GitHub Packages URL:

```xml
<distributionManagement>
  <repository>
    <id>github</id>
    <name>GitHub Packages</name>
    <url>https://maven.pkg.github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME</url>
  </repository>
</distributionManagement>
```

### 3. Disable SonarCloud Automatic Analysis

In SonarCloud: **Administration → Analysis Method → Automatic Analysis → OFF**

### 4. Apply Terraform

```bash
terraform init
terraform apply
```

This provisions all AWS infrastructure and automatically injects the following secrets into your GitHub repository:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `ECR_REPO_NAME` | ECR repository name |
| `SONAR_TOKEN` | SonarCloud token |
| `SONAR_PROJECT_KEY` | SonarCloud project key |
| `SONAR_ORG` | SonarCloud organisation |

### 5. Push to main

```bash
git push origin main
```

The pipeline fires automatically. Job 1 runs tests and analysis. If all pass, Job 2 builds and pushes the Docker image to ECR.

---

## Secrets reference

All secrets are injected by Terraform. No manual configuration in the GitHub UI is needed.

| Secret | Source | Used by |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | `aws_iam_access_key.github_actions` | Job 2 — ECR login |
| `AWS_SECRET_ACCESS_KEY` | `aws_iam_access_key.github_actions` | Job 2 — ECR login |
| `ECR_REPO_NAME` | `module.ecs.ecr_repo_name` | Job 2 — docker push |
| `SONAR_TOKEN` | `var.sonar_token` | Job 1 — SonarCloud |
| `SONAR_PROJECT_KEY` | `var.sonar_project_key` | Job 1 — SonarCloud |
| `SONAR_ORG` | `var.sonar_org` | Job 1 — SonarCloud |
| `GITHUB_TOKEN` | Built-in (GitHub provides) | Job 1 — GitHub Packages |

---

## Tear down

```bash
cd terraform
terraform destroy
```

This removes all AWS resources and the GitHub secrets. The ECR repository has `force_delete = true` so it is deleted even if it contains images.


## Limitations 

The limitation on this project is that is can only deploy once in a single environment and the terraform state file is stored locally on the developers PC.


## Improvements

The project can be refactored into a multiples environments like (dev, stagging and prod).
And the state file can be stored in a terraform cloud or object storage like S3 bucket.


## Result

The final outputs when the LoadBalancer DNS is been accessed See the systems/ folder for result.png
Ensure that when accessing the LoadBalancer DNS it should be http:// not https:// because a certificate is not attached to the LoadBalancer.