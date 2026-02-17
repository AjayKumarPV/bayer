resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "bayer-vpc"
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  

  tags = {
    Name = "bayer-igw"
  }
  
}


resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "bayer-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "bayer-public-subnet-2"
  }
}




resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "bayer-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "bayer-private-subnet-b"
  }
}



resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "bayer-public-rt"
  }
}




resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_eip" "nat_eip" {
  domain = "vpc"
}


resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "bayer-nat"
  }

  depends_on = [aws_internet_gateway.igw]

}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "bayer-private-rt"
  }
}


resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "app_sg" {
  name   = "app-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_iam_role" "ec2_role" {
  name = "bayer-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}



resource "aws_iam_instance_profile" "ec2_profile" {
  name = "bayer-ec2-profile"
  role = aws_iam_role.ec2_role.name
}



data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_caller_identity" "current" {}


resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name = var.key_name

  tags = {
    Name = "bayer-bastion"
  }
}


resource "aws_launch_template" "app_lt" {
  name_prefix   = "bayer-app-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  depends_on = [aws_nat_gateway.nat]

  vpc_security_group_ids = [aws_security_group.app_sg.id]


  user_data = base64encode(<<EOF
#!/bin/bash
dnf update -y
dnf install -y python3 git

python3 -m ensurepip --upgrade
python3 -m pip install --upgrade pip
python3 -m pip install django gunicorn

cd /home/ec2-user

# Create Django project
django-admin startproject mysite
cd mysite

# Create polls app
python3 manage.py startapp polls

# Create view
cat > polls/views.py <<EOL
from django.http import HttpResponse

def index(request):
    return HttpResponse("Hello, world. You're at the polls index.")
EOL

# Create polls urls
cat > polls/urls.py <<EOL
from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),
]
EOL

# Update main urls.py
cat > mysite/urls.py <<EOL
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('', include('polls.urls')),
    path('admin/', admin.site.urls),
]
EOL

python3 manage.py migrate

# Allow external access
sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" mysite/settings.py

nohup gunicorn --bind 0.0.0.0:8000 mysite.wsgi:application > /home/ec2-user/gunicorn.log 2>&1 &
EOF
  )
}





resource "aws_lb" "app_alb" {
  name               = "bayer-alb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  security_groups    = [aws_security_group.alb_sg.id]
  enable_deletion_protection = false

  tags = {
    Name = "bayer-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "bayer-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}



resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


resource "aws_autoscaling_group" "app_asg" {
  name                      = "bayer-app-asg"
  desired_capacity          = 1
  max_size                  = 2
  min_size                  = 1
  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  target_group_arns         = [aws_lb_target_group.app_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}



