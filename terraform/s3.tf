module "s3" {
  for_each           = var.s3_bucket
  source             = "./modules/s3"
  project_name       = var.project_name
  bucket_name        = "${var.project_name}-s3-${each.key}"
  versioning_enabled = var.versioning_enabled
  lifecycle_days     = 30
  tags = {
    Name = "${var.project_name}-app-bucket"
  }
}