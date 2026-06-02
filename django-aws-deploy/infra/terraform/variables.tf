variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short project identifier used for resource naming"
  type        = string
  default     = "django-app"
}

variable "environment" {
  description = "Deployment environment (production / staging)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "trusted_ssh_cidr" {
  description = "CIDR allowed to SSH (your static IP or VPN endpoint, e.g. 1.2.3.4/32)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material to upload as a key pair"
  type        = string
  sensitive   = true
}
