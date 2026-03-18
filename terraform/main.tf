# -------------------------------------------------------
# SECURITY GROUP
# Controls inbound/outbound traffic for the EC2 instance.
# -------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "Allow HTTP, HTTPS, and SSH inbound traffic"

  # SSH — restrict to your IP in production (0.0.0.0/0 is open to the world)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (needed for apt-get, certbot, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# EC2 INSTANCE
# -------------------------------------------------------
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.web.id]

  # user_data runs ONCE on first boot as root.
  # It installs Nginx and deploys the initial site.
  user_data = file("${path.module}/../scripts/setup.sh")

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# ELASTIC IP
# Gives the instance a static public IP that survives reboots.
# Without this, the IP changes every time you stop/start the instance.
# -------------------------------------------------------
resource "aws_eip" "web" {
  instance = aws_instance.web.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

# -------------------------------------------------------
# ROUTE 53 DNS (Stretch Goal — only created if domain_name is set)
# -------------------------------------------------------
data "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

resource "aws_route53_record" "www" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.web.public_ip]
}
