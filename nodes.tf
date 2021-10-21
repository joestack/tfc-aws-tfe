
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
              #echo "${local.lic_rli}" > /home/ubuntu/license.rli
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
  count                       = var.tfe_node_install
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


resource "aws_instance" "keycloak_node" {
  count                       = var.kk_node_install
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.dmz_subnet.id
  private_ip                  = cidrhost(aws_subnet.dmz_subnet.cidr_block, 200)
  associate_public_ip_address = "true"
  vpc_security_group_ids      = [aws_security_group.tfe.id]
  key_name                    = var.pub_key


  tags = {
    Name        = format("kk-%02d", count.index + 1)
  }

  user_data = file("./templates/kk_userdata.sh")
}

resource "aws_route53_record" "kknode" {
  count   = var.kk_node_install
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = lookup(aws_instance.keycloak_node.*.tags[count.index], "Name")
  type    = "A"
  ttl     = "300"
  records = [element(aws_instance.keycloak_node.*.public_ip, count.index )]
  #[aws_instance.tfe_nodes.public_ip]
}

resource "aws_security_group" "kk" {
  name        = "${var.name}-kk-sg"
  description = "private keycloak"
  vpc_id      = aws_vpc.hashicorp_vpc.id
}

resource "aws_security_group_rule" "kk-http" {
  security_group_id = aws_security_group.kk.id
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "kk-https" {
  security_group_id = aws_security_group.kk.id
  type              = "ingress"
  from_port         = 8443
  to_port           = 8443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "kk-management" {
  security_group_id = aws_security_group.kk.id
  type              = "ingress"
  from_port         = 9990
  to_port           = 9990
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "kk-egress" {
  security_group_id = aws_security_group.kk.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}