provider "aws" {
  region = "us-east-1" 
}

resource "aws_vpc" "Marwan_VPC" {
  cidr_block = "17.0.0.0/16"
  tags = {
    Name = "Marwan_VPC"
  }
}

resource "aws_subnet" "marwan_subnet_1" {
  vpc_id     = aws_vpc.Marwan_VPC.id
  cidr_block = "17.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "marwan-subnet-1"
  }
}

resource "aws_subnet" "marwan_subnet_2" {
  vpc_id     = aws_vpc.Marwan_VPC.id
  cidr_block = "17.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "marwan-subnet-2"
  }
}

resource "aws_internet_gateway" "marwan_igw" {
  vpc_id = aws_vpc.Marwan_VPC.id
  tags = {
    Name = "marwan-igw"
  }
}

resource "aws_route_table" "marwan_route_table" {
  vpc_id = aws_vpc.Marwan_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.marwan_igw.id
  }

  tags = {
    Name = "marwan-route-table"
  }
}

resource "aws_route_table_association" "marwan_rta_1" {
  subnet_id      = aws_subnet.marwan_subnet_1.id
  route_table_id = aws_route_table.marwan_route_table.id
}

resource "aws_route_table_association" "marwan_rta_2" {
  subnet_id      = aws_subnet.marwan_subnet_2.id
  route_table_id = aws_route_table.marwan_route_table.id
}

resource "aws_security_group" "marwan_sg" {
  vpc_id = aws_vpc.Marwan_VPC.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "marwan-security-group"
  }
}



resource "aws_instance" "MarwanVM1" {
  ami           = "ami-0a0e5d9c7acc336f1"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.marwan_subnet_1.id
  vpc_security_group_ids = [aws_security_group.marwan_sg.id]
  associate_public_ip_address = true
  //key_name = "Ins1"
  tags = {
    Name = "MarwanVM1"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker $USER
	      echo "<html><body><h1>Welcome to MarwanVM_1</h1></body></html>" > /home/ubuntu/index.html
	      sudo docker pull nginx
	      sudo docker run -d -p 80:80 -v /home/ubuntu/index.html:/usr/share/nginx/html/index.html nginx
              EOF
}

resource "aws_instance" "MarwanVM2" {
  ami           = "ami-0a0e5d9c7acc336f1"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.marwan_subnet_2.id
  vpc_security_group_ids = [aws_security_group.marwan_sg.id]
  associate_public_ip_address = true
  //key_name = "Ins1"
  tags = {
    Name = "MarwanVM2"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker $USER
	      echo "<html><body><h1>Welcome to MarwanVM_2</h1></body></html>" > /home/ubuntu/index.html
	      sudo docker pull nginx
	      sudo docker run -d -p 80:80 -v /home/ubuntu/index.html:/usr/share/nginx/html/index.html nginx
              EOF
}

resource "aws_alb" "Marwan_ALB" {
  name               = "Marwan-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.marwan_sg.id]
  subnets            = [aws_subnet.marwan_subnet_1.id, aws_subnet.marwan_subnet_2.id]

  enable_deletion_protection = false
  idle_timeout               = 60
  drop_invalid_header_fields = true

  tags = {
    Name = "Marwan-ALB"
  }
}


resource "aws_alb_target_group" "marwan_tg" {
  name     = "marwan-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Marwan_VPC.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
  //  port                = "80"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "marwan-target-group"
  }
}


resource "aws_alb_listener" "Marwan_listener" {
  load_balancer_arn = aws_alb.Marwan_ALB.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.marwan_tg.arn
  }
}


resource "aws_alb_target_group_attachment" "MarwanVM1_attachment" {
  target_group_arn = aws_alb_target_group.marwan_tg.arn
  target_id        = aws_instance.MarwanVM1.id
  port             = 80
}


resource "aws_alb_target_group_attachment" "MarwanVM2_attachment" {
  target_group_arn = aws_alb_target_group.marwan_tg.arn
  target_id        = aws_instance.MarwanVM2.id
  port             = 80
}

resource "aws_ecr_repository" "marwan_ecr" {
  name = "marwan-ecr-repo"

  tags = {
    Name = "marwan-ecr"
  }
}


