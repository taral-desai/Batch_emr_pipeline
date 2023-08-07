output "private_key" {
  description = "EC2 private key."
  value       = tls_private_key.rsa_4096_airflow_ec2.private_key_pem
  sensitive   = true
}

output "public_key" {
  description = "EC2 public key."
  value       = tls_private_key.rsa_4096_airflow_ec2.public_key_openssh
}