output "control_plane_public_ip" {
  description = "Public IP of the control plane EC2 instance"
  value       = aws_instance.control_plane.public_ip
}