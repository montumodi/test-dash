resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dash-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "dash-internet-gateway"
  }
}

resource "aws_subnet" "public-subet-zone-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "dash-public-subnet-1"
  }
}

resource "aws_subnet" "public-subet-zone-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "dash-public-subnet-2"
  }
}

resource "aws_subnet" "private-subet-zone-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "dash-private-subnet-1"
  }
}

resource "aws_subnet" "private-subet-zone-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "dash-private-subnet-2"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "dash-public-route-table"
  }
}

resource "aws_route_table_association" "public-subnet-public-route-table-a" {
  subnet_id      = aws_subnet.public-subet-zone-a.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "public-subnet-public-route-table-b" {
  subnet_id      = aws_subnet.public-subet-zone-b.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_eip" "elastic-ip" {
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "dash-public-nat-gateway" {
  allocation_id = aws_eip.elastic-ip.allocation_id
  subnet_id     = aws_subnet.public-subet-zone-a.id

  tags = {
    Name = "dash-public-nat-gateway"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.dash-public-nat-gateway.id
  }

  tags = {
    Name = "dash-private-route-table"
  }
}

resource "aws_route_table_association" "private-subnet-public-route-table-a" {
  subnet_id      = aws_subnet.private-subet-zone-a.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "private-subnet-public-route-table-b" {
  subnet_id      = aws_subnet.private-subet-zone-b.id
  route_table_id = aws_route_table.private-route-table.id
}