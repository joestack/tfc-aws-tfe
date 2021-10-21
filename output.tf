output "Bastionhost_public_IP" {
  value = "ssh ${var.ssh_user}@${aws_instance.bastionhost.public_ip}"
}

output "Keycloak_public_IP" {
  value = "ssh ${var.ssh_user}@${aws_instance.keycloak_node.*.public_ip}"
}

output "Bastionhost_DNS" {
  value = aws_route53_record.bastionhost.name
}

output "Terraform_DNS" {
  value = aws_route53_record.tfenodes.*.name
}

output "Backup_Token" {
  value = random_string.settings_backup_token.result
}

# output "inventory" {
#   value = data.template_file.ansible_skeleton.rendered
# }

# output "ansible_hosts" {
#   value = data.template_file.ansible_tfe_hosts.*.rendered
# }

# output "tfe_node_ips" {
#   value = aws_instance.tfe_nodes.*.private_ip
# }

