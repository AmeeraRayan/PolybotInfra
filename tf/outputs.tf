output "control_plane_public_ip" {
  description = "Public IP of the control plane EC2 instance"
  value       = module.k8s_cluster.control_plane_public_ip
}
output "worker_asg_name" {
  description = "Auto Scaling Group name for worker nodes"
  value = module.k8s_cluster.worker_asg_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.k8s_cluster.telegram_alb_dns
}