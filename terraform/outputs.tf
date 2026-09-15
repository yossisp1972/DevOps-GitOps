output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k3s.id
}

output "public_ip" {
  description = "K3s server public IP"
  value       = aws_instance.k3s.public_ip
}

output "ssh_command" {
  description = "Example SSH command"
  value       = "ssh ubuntu@${aws_instance.k3s.public_ip}"
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_id" {
  value = aws_subnet.public.id
}
