terraform {
  backend "s3" {
    bucket         = "champions-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical's AWS account ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_security_group" "ssh_access" {
  name        = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting this to GitHub Actions IP ranges for better security
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "example" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # SSH connection configuration for provisioners
  connection {
    type        = "ssh"
    user        = "ubuntu"  # Default user for Ubuntu AMIs
    private_key = file(var.private_key_path)  # Path to the SSH private key
    host        = self.public_ip
  }


  provisioner "local-exec" {
  command = "sleep 60"  # Waits 60 seconds
  }

  provisioner "file" {
    #source      = "index.html"
    #destination = "/var/www/html/index.html"
    source      = "index.html"
    destination = "/tmp/index.html"  # Use a temporary directory
  
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y apache2",
      #"sudo mv /var/www/html/index.html /var/www/html/",
      "sudo mv /tmp/index.html /var/www/html/index.html",  # Move it with sudo
      "sudo chown www-data:www-data /var/www/html/index.html",  # Set ownership
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2"
    ]
  }

  tags = {
    Name = var.name
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              EOF

  lifecycle {
    create_before_destroy = true
  }
}
