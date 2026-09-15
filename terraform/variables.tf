variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type used for K3s"
  type        = string
  default     = "t3.medium"
}

  validation {
    condition     = var.allowed_ssh_cidr != "0.0.0.0/0"
    error_message = "Do not expose SSH to the entire internet. Supply your public IP as x.x.x.x/32."
  }
}

