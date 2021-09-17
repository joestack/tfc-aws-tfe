# tfc-aws-tfe

The purpose of this Terraform repo is to install pTFE on AWS. It will create a bastion host and a terraform node. The bastion host is used to execute a ansible playbook on the terraform node. That playbook contains 3 roles. common - for some OS basics, create_cert - to create a Let's Encrypt TLS cert, ptfe - to setup Terraform Enterprise.


There are some prerequisites that you need to take care of:

- you need a Terraform Enterprise license (license.rli). That license need to be stored as a base64 encoded variable (var.tfe_rli).
- a public ssh key that is used to get access to the bastion host should already be available within the selected AWS region. In my case the key is named "joestack" and exists already on AWS.
- you need the corresponding private ssh key to be stored as a base64 encoded variable (var.pri_key). That key is used by the bastion host to get access the terraform node and to execute the ansible playbook that configures Terraform Enterprise. Therefore the ssh keypair shouldn't contain a passphrase!
- you need to define the encryption key that is used by Terraform to encrypt any data stored on mounted disk or on externals services (state-files and database content). This encryption key is stored as variable (var.tfe_encryption_key).
- you need to store the initial admin password the is used to get access to the replicated admin site as var.tfe_password
- you need a Route53 domain that is accessible by your AWS cloud subscription (joestack.xyz in my case).
- finally you have to define a unique name for your installation as var.name


| Filename     | Description |
| ------------ | ----------------------- |
| variables.tf |  the place to start ;-) |
| outputs.tf   | outputs after execution |
| main.tf      | network, security groups |
| nodes.tf     | bastion host, TFE node  |
| inventory.tf | creates ansible inventory, renders all templates, executes the playbook|
| /templates   | contains all templates to be rendered |
| /ansible     | contains the entire playbook to setup Terraform |






