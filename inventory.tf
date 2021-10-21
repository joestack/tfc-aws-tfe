
data "template_file" "ansible_tfe_hosts" {
  count      = var.tfe_node_install
  template   = file("${path.root}/templates/ansible_hosts.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    node_name    = aws_instance.tfe_nodes.*.tags[count.index]["Name"]
    ansible_user = var.ssh_user
    ip           = element(aws_instance.tfe_nodes.*.private_ip, count.index)
  }
}


data "template_file" "ansible_skeleton" {
  count      = var.tfe_node_install
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
  count      = var.tfe_node_install
  depends_on = [data.template_file.ansible_skeleton]

  content  = data.template_file.ansible_skeleton.*.rendered
  filename = "${path.root}/inventory"
}

##
## copy the local file to the tfe_node
##
resource "null_resource" "provisioner" {
  count      = var.tfe_node_install
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




### CERTBOT Playbook role create_cert - modify the email address relatet to the TLS cert 
data "template_file" "ansible_certbot" {
  count      = var.tfe_node_install
  template   = file("${path.root}/templates/certbot.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    email        = var.email
    domain       = var.dns_domain
  }
}

#and create a local copy of that main.yml on the exec environment 
resource "local_file" "ansible_certbot" {
  count      = var.tfe_node_install
  depends_on = [data.template_file.ansible_certbot]

  content  = data.template_file.ansible_certbot.*.rendered
  filename = "${path.root}/ansible/roles/create_cert/tasks/main.yml"
}

# Playbook file replicated.conf

data "template_file" "ansible_replicated" {
  count      = var.tfe_node_install
  template   = file("${path.root}/templates/replicated.conf.tpl")
  depends_on = [aws_instance.tfe_nodes]

  vars = {
    tfe_password = var.tfe_password
    domain       = var.dns_domain
    hostname     = lookup(aws_instance.tfe_nodes.*.tags[0], "Name")

  }
}

resource "local_file" "ansible_replicated" {
  count      = var.tfe_node_install
  depends_on = [data.template_file.ansible_replicated]

  content  = data.template_file.ansible_replicated.*.rendered
  filename = "${path.root}/ansible/roles/ptfe/files/replicated.conf"
}


# Playbook file settings.json

resource "random_string" "settings_backup_token" {
  length           = 32
  special          = false
}


data "template_file" "ansible_settings" {
  count      = var.tfe_node_install
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
  count      = var.tfe_node_install
  depends_on = [data.template_file.ansible_settings]

  content  = data.template_file.ansible_settings.*.rendered
  filename = "${path.root}/ansible/roles/ptfe/files/settings.json"
}

##
## here we copy the entire Ansible Playbook from the local executin entironment to the Bastionhost
##
resource "null_resource" "cp_ansible" {
  count      = var.tfe_node_install
  depends_on = [
    null_resource.provisioner,
    local_file.ansible_certbot,
    local_file.ansible_replicated,
    local_file.ansible_settings
    ]

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

#local-exec to generate the license.rli file on exec environment
#copy the file to the ansible dir ansible/roles/ptfe/files

resource "null_resource" "license" {
  depends_on = [null_resource.cp_ansible]
  
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
      "echo ${local.lic_rli} > ~/ansible/roles/ptfe/files/license.rli",
    ]
  }
}


##
## here we trigger the execution of the Ansible Playbook automatically with every Terraform run
##
resource "null_resource" "ansible_run" {
  depends_on = [
    null_resource.cp_ansible,
    null_resource.provisioner,
    null_resource.license,
    aws_instance.tfe_nodes,
    aws_route53_record.bastionhost
  ]
    
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
      "sleep 60 && ansible-playbook -i ~/inventory ~/ansible/playbook.yml ",
    ]
  }
}