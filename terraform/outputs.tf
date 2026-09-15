output "instance_id" {
  description = "K3s EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "Public IP of K3s EC2 instance"
  value       = aws_instance.k3s.public_ip
}

output "ssm_command" {
  description = "Command to connect using AWS Systems Manager"
  value       = "aws ssm start-session --target ${aws_instance.k3s.id}"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for demo application"
  value       = aws_ecr_repository.demo_app.repository_url
}
