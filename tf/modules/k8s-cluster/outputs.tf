output "control_plane_public_ip" {
  description = "Elastic IP of the control plane EC2 instance"
  value       = aws_eip.control_plane_eip.public_ip
}

output "worker_asg_name" {
  description = "Name of the Auto Scaling Group for workers"
  value       = aws_autoscaling_group.worker_asg.name
}
output "telegram_alb_dns" {
  description = "DNS name of the ALB"
  value       = aws_lb.telegram_alb.dns_name
}