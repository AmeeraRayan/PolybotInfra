output "control_plane_public_ip" {
  description = "Elastic IP of the control plane EC2 instance"
  value       = aws_eip.control_plane_eip.public_ip
}