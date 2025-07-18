# Security Group for Terraform Enterprise Instance
resource "aws_security_group" "terraform_enterprise" {
  name        = "${var.tfe_project_name}-sg"
  description = "Security group for Terraform Enterprise instance"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.aws_security_group.bastion.id]
  }

  ingress {
    description = "TFE Application from VPC"
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description     = "TFE Application from bastion"
    from_port       = 8800
    to_port         = 8800
    protocol        = "tcp"
    security_groups = [data.aws_security_group.bastion.id]
  }

  ingress {
    description = "TFE API from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description     = "TFE API from bastion"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [data.aws_security_group.bastion.id]
  }

  ingress {
    description = "HTTP redirect from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }

  # Allow additional CIDR blocks if specified
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "TFE Application from allowed CIDRs"
      from_port   = 8800
      to_port     = 8800
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      description = "TFE API from allowed CIDRs"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.tfe_project_name}-sg"
  }
}
