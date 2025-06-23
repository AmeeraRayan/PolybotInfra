output "control_plane_public_ip" {
  description = "Public IP of the control plane EC2 instance"
  value       = module.k8s_cluster.control_plane_public_ip
}