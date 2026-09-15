provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "k3s-devops-lab"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
