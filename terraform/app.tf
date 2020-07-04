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
  name_prefix            = "app"
  image_id               = data.aws_ami.app.image_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_http.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix         = "autoscaling-poc-app"
  max_size            = 2
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.private.id]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}
