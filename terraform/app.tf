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
  user_data              = filebase64("${path.module}/files/user-data.sh")

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
    version = aws_launch_template.app.latest_version
  }
}

resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "app" {
  bucket        = "asg-app-poc-${random_id.bucket.hex}"
  acl           = "private"
  force_destroy = true

  tags = {
    Name = "asg-app-poc"
  }
}

resource "aws_ssm_parameter" "app_bucket" {
  name  = "app-bucket-name"
  type  = "String"
  value = aws_s3_bucket.app.id
}

data "aws_iam_policy_document" "app_s3_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app.arn}/*"]
  }

  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.app_bucket.arn]
  }
}

resource "aws_iam_policy" "app_s3_access" {
  name        = "autoscaling-app-poc-s3-access"
  description = "Policy that allows read-only access to the S3 bucket containing application code"
  policy      = data.aws_iam_policy_document.app_s3_access.json
}

resource "aws_iam_role_policy_attachment" "app_s3_access" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_s3_access.arn

  depends_on = [
    aws_iam_role.app
  ]
}
