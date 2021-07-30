
# INSTANCES

resource "aws_instance" "bastionhost" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 10)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.bastionhost.id]
  key_name                    = var.pub_key

  user_data = <<-EOF
              #!/bin/bash
              echo "${local.lic_rli}" > /home/ubuntu/license.rli
              echo "${local.priv_key}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible -y 
              EOF

  tags = {
    Name        = "bastionhost-${var.name}"
  }
}

resource "aws_instance" "tfe_nodes" {
  count                       = var.tfe_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 100)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.tfe.id]
  key_name                    = var.pub_key


  tags = {
    Name        = format("tfe-%02d", count.index + 1)
  }


  ebs_block_device {
      device_name = "/dev/xvdb"
      volume_type = "gp2"
      volume_size = 40
    }

  ebs_block_device {
      device_name = "/dev/xvdc"
      volume_type = "gp2"
      volume_size = 20
    }

  user_data = file("./templates/userdata.sh")
}


