data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_vpc" "open_web_ui" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_subnet" "open_web_ui_subnet" {
  vpc_id     = aws_vpc.open_web_ui.id
  cidr_block = cidrsubnet(aws_vpc.open_web_ui.cidr_block, 8, 1)

  tags = {
    Name = "demo"
  }
}

resource "aws_internet_gateway" "open_web_ui_gw" {
  vpc_id = aws_vpc.open_web_ui.id

  tags = {
    Name = "demo"
  }
}

resource "aws_route_table" "open_web_ui_rt" {
  vpc_id = aws_vpc.open_web_ui.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.open_web_ui_gw.id
  }

  tags = {
    Name = "demo"
  }
}

resource "aws_route_table_association" "open_web_ui" {
  subnet_id      = aws_subnet.open_web_ui_subnet.id
  route_table_id = aws_route_table.open_web_ui_rt.id
}


resource "aws_security_group" "ssh" {
  name = "allo-all"

  vpc_id = aws_vpc.open_web_ui.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "tcp" {
  name = "allo-tcp"

  vpc_id = aws_vpc.open_web_ui.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_key_pair" "riyadi-key" {
  key_name   = "riyadi-key"
  public_key = file("C:/Users/USER/Documents/rose/key/id_rsa.pub")
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# Request a spot instance at $0.03
resource "aws_spot_instance_request" "open_web_ui" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  tags = {
    Name = "demo"
  }

  associate_public_ip_address = true
  key_name                    = aws_key_pair.riyadi-key.key_name
  vpc_security_group_ids      = [aws_security_group.ssh.id, aws_security_group.tcp.id]
  subnet_id                   = aws_subnet.open_web_ui_subnet.id
  wait_for_fulfillment        = true

  user_data_base64 = base64encode(templatefile("provision_basic.sh", {
    open_webui_user         = var.open_webui_user
    open_webui_password_b64 = base64encode(random_password.password.result)
  }))

}



resource "terracurl_request" "check_open_web_ui" {
  url    = "http://${aws_spot_instance_request.open_web_ui.public_ip}:3000/api/health"
  method = "GET"
  name   = "check_open_web_ui"

  response_codes = [200]
  max_retry      = 150
  retry_interval = 10

}
