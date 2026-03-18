output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "The Elastic IP address of the web server"
  value       = aws_eip.web.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_eip.web.public_ip}"
}

output "site_url" {
  description = "URL of the deployed site"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_eip.web.public_ip}"
}
