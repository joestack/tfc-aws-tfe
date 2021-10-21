variable "aws_region" {
  description = "AWS region"
  default     = "eu-west-1"
}

variable "name" {
  description = "Unique name of the deployment"
}

variable "email" {
  description = "Email to be used for the certbot"
  default     = "joern@hashicorp.com"
}

variable "tfe_node_install" {
  description = "1=yes, 0=no"
  default     = "0"
}

variable "instance_type" {
  description = "instance size to be used for worker nodes"
  default     = "t2.medium"
}


variable "ssh_user" {
  description = "default ssh user to get access to an instance"
  default     = "ubuntu"
}

variable "pub_key" {
  description = "the public key to be used to access the bastion host and ansible nodes"
  default     = "joestack"
}

variable "pri_key" {
  description = "the base64 encoded private key to be used to access the bastion host and ansible nodes"
}

variable "dns_domain" {
  description = "DNS domain suffix"
  default     = "joestack.xyz"
}

variable "network_address_space" {
  description = "CIDR for this deployment"
  default     = "192.168.0.0/16"
}

variable "tfe_password" {}
variable "tfe_encryption_key" {}
variable "tfe_rli" {}

locals {
  priv_key = base64decode(var.pri_key)
  lic_rli  = base64decode(var.tfe_rli)
}
