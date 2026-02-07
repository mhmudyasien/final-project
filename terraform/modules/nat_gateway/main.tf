resource "aws_eip" "this" {
  tags = {
    Name = var.name
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = var.public_subnet_id
  tags = {
    Name = var.name
  }
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}
