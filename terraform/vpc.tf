# VPC CONFIG
data "aws_availability_zones" "zones" {
  state = "available"
}

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
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "autoscaling-poc-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = data.aws_availability_zones.zones.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "autoscaling-poc-public-b"
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
  subnet_id     = aws_subnet.public_a.id

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

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
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

