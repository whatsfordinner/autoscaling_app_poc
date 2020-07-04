provider "aws" {}

data "aws_availability_zones" "zones" {
  state = "available"
}

# VPC CONFIG
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "austoscaling-poc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "autoscaling-poc"
  }
}

# SUBNET CONFIG
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "autoscaling-poc-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = data.aws_availability_zones.zones.names[0]

  tags = {
    Name = "autoscaling-poc-private"
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true

  tags = {
    Name = "autoscaling-poc-natgw"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "autoscaling-poc"
  }
}

# ROUTE TABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "autoscaling-poc-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "autoscaling-poc-private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# APPLICATION
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["autoscaling-poc-*"]
  }
}

data "aws_iam_policy_document" "app_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "autoscaling-poc-app-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json
}

resource "aws_iam_instance_profile" "app" {
  name = "autoscaling-poc-app-instance-profile"
  role = aws_iam_role.app.name

  depends_on = [
    aws_iam_role.app
  ]
}

resource "aws_iam_role_policy_attachment" "ssm_access_for_app" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

  depends_on = [
    aws_iam_role.app
  ]
}

resource "aws_security_group" "app_http" {
  name        = "autoscaling-poc-app"
  description = "Allows HTTP traffic from within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from within VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "autoscaling-poc-app"
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "app"
  image_id      = data.aws_ami.app.image_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_http.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }
}

resource "aws_autoscaling_group" "app" {
  availability_zones = [aws_subnet.private.availability_zone]
  name_prefix = "autoscaling-poc-app"
  max_size = 2
  min_size = 2
  vpc_zone_identifier = [aws_subnet.private.id]

  launch_template {
    id = aws_launch_template.app.id
    version = "$Latest"
  }
}