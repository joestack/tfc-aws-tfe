
data "template_file" "ansible_tfe_hosts" {
  count      = var.tfe_node_count
  template   = file("${path.root}/templates/ansible_hosts.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    node_name    = aws_instance.tfe_nodes.*.tags[count.index]["Name"]
    ansible_user = var.ssh_user
    ip           = element(aws_instance.tfe_nodes.*.private_ip, count.index)
  }
}


data "template_file" "ansible_skeleton" {
  template = file("${path.root}/templates/ansible_skeleton.tpl")

  vars = {
    tfe_hosts_def = join("", data.template_file.ansible_tfe_hosts.*.rendered)
  }
}


##
## here we write the rendered Inventory-File to a local file
## on the Terraform exec environment 
##
resource "local_file" "ansible_inventory" {
  depends_on = [data.template_file.ansible_skeleton]

  content  = data.template_file.ansible_skeleton.rendered
  filename = "${path.root}/inventory"
}

##
## copy the local file to the tfe_node
##
resource "null_resource" "provisioner" {
  depends_on = [local_file.ansible_inventory]

  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.root}/inventory"
    destination = "~/inventory"

    connection {
      type        = "ssh"
      host        = aws_instance.bastionhost.public_ip
      user        = var.ssh_user
      private_key = local.priv_key
      insecure    = true
    }
  }
}


#local-exec to generate the license.rli file on exec environment
#copy the file to the ansible dir ansible/roles/ptfe/files

resource "null_resource" "license" {
  depends_on = [data.template_file.ansible_replicated]
  provisioner "local-exec" {
    command = "echo ${local.lic_rli} > ${path.root}/ansible/roles/ptfe/files/license.rli" 
  }
}

### CERTBOT Playbook task
data "template_file" "ansible_certbot" {
  template   = file("${path.root}/templates/certbot.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    email        = var.email
    domain       = var.dns_domain
  }
}

resource "local_file" "ansible_certbot" {
  depends_on = [data.template_file.ansible_certbot]

  content  = data.template_file.ansible_certbot.rendered
  filename = "${path.root}/ansible/roles/create_cert/tasks/main.yml"
}

# Playbook file replicated.conf

data "template_file" "ansible_replicated" {
  template   = file("${path.root}/templates/replicated.conf.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    tfe_password = var.tfe_password
    domain       = var.dns_domain
    hostname     = lookup(aws_instance.tfe_nodes.*.tags[0], "Name")

  }
}

resource "local_file" "ansible_replicated" {
  depends_on = [data.template_file.ansible_replicated]

  content  = data.template_file.ansible_replicated.rendered
  filename = "${path.root}/ansible/roles/ptfe/files/replicated.conf"
}


# Playbook file settings.json

resource "random_string" "settings_backup_token" {
  length           = 32
  special          = false
}


data "template_file" "ansible_settings" {
  template   = file("${path.root}/templates/settings.json.tpl")
  depends_on = [
                aws_instance.tfe_nodes,
                random_string.settings_backup_token
  ]

  vars = {
    tfe_encryption_key = var.tfe_encryption_key
    domain             = var.dns_domain
    hostname           = lookup(aws_instance.tfe_nodes.*.tags[0], "Name")
    backup_token       = random_string.settings_backup_token.result
  }
}

resource "local_file" "ansible_settings" {
  depends_on = [data.template_file.ansible_settings]

  content  = data.template_file.ansible_settings.rendered
  filename = "${path.root}/ansible/roles/ptfe/files/settings.json"
}

##
## here we copy the Ansible Playbook to the Bastionhost
##
resource "null_resource" "cp_ansible" {
  depends_on = [null_resource.provisioner]

  triggers = {
    always_run = timestamp()
  }

  provisioner "file" {
    source      = "${path.root}/ansible"
    destination = "~/"

    connection {
      type        = "ssh"
      host        = aws_instance.bastionhost.public_ip
      user        = var.ssh_user
      private_key = local.priv_key
      insecure    = true
    }
  }
}

# # cp Ansible Vault decryption key to bastionhost
# resource "null_resource" "vault_encryption_key" {
#   depends_on = [
#     null_resource.cp_ansible
#   ]

#   triggers = {
#     always_run = timestamp()
#   }

#   connection {
#     type        = "ssh"
#     host        = aws_instance.bastionhost.public_ip
#     user        = var.ssh_user
#     private_key = local.priv_key
#     insecure    = true
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo ${var.tfe_rli_vault_password} > ~/.vault-pw.txt ",
#     ]
#   }
# }


##
## here we trigger the execution of the Ansible Playbook automatically with every Terraform run
##
resource "null_resource" "ansible_run" {
  depends_on = [
    null_resource.cp_ansible,
    null_resource.provisioner,
    local_file.ansible_settings,
    local_file.ansible_replicated,
    aws_instance.tfe_nodes,
    aws_route53_record.bastionhost
  ]
    #local_file.ansible_inventory,
    
  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    host        = aws_instance.bastionhost.public_ip
    user        = var.ssh_user
    private_key = local.priv_key
    insecure    = true
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'ssh is up...'",
      #"[ -e ~/ansible/roles/ptfe/files/license.rli ] && ansible-vault decrypt ~/ansible/roles/ptfe/files/license.rli --vault-password-file=~/.vault-pw.txt ",
      "sleep 60 && ansible-playbook -i ~/inventory ~/ansible/playbook.yml ",
    ]
  }
}