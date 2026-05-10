# Global Variables
project_name = "newbank"
environment  = "dev"
region       = "eu-west-1"



vpc_cidr = "10.0.1.0/16"


s3_bucket = {
  "app-data" = {} # Uses default module values
  # "user-assets" = {}
}

alb = {
  "app-alb" = {
    # ALB Configuration
  }
}