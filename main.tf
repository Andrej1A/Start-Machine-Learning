terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.16.0"
    }
  }
}

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "eu-west-1"
}

resource "aws_instance" "gpu_server" {
    # ami in region (eu-west-1) - Deep Learning AMI (Ubuntu 18.04) Version 60.4
    ami = "ami-07afb32b4cb2c5c44" # the ami-id depends on your region
    instance_type = "g3s.xlarge"
    key_name = "${var.aws_key_pair_name}"
    vpc_security_group_ids = [aws_security_group.main.id]

    provisioner "remote-exec" {
      inline = [
        "touch hello_world.txt",
        "echo helloworld >> hello_world.txt",
        "mkdir workspace",
        "sudo mount /dev/xvdb1 workspace",
        "sudo chown ubuntu:ubuntu workspace/",
        "sudo chmod 775 workspace/",
      ]
    }
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("${var.ssh_private_key_file_path}")
      timeout     = "7m"
   }
   tags = {
     Name = "GPU-Server"
   }
}

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = [ "0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
 ingress                = [
   {
     cidr_blocks      = [ "0.0.0.0/0", ]
     description      = ""
     from_port        = 22
     ipv6_cidr_blocks = []
     prefix_list_ids  = []
     protocol         = "tcp"
     security_groups  = []
     self             = false
     to_port          = 22
     self = false
  },
  {
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow ping from 0.0.0.0/0 everywhere"
    self = false
  }
  ]

}

resource "aws_ebs_volume" "ml_dataset_volume" {
  availability_zone = "eu-west-1b"
  size = 200
  encrypted = false
  # skip_destroy  = true
  tags = {
    Name = "ml_dataset"
  }
}

resource "aws_volume_attachment" "attach_ml_dataset_volume_to_gpuserver1" {
  device_name = "/dev/xvdb"
  instance_id = aws_instance.gpu_server.id
  volume_id = aws_ebs_volume.ml_dataset_volume.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.aws_key_pair_name}"
  public_key = "${var.ssh_public_key}"
}

resource "aws_eip" "gpu_server_ip" {
  instance = aws_instance.gpu_server.id
  vpc      = true
  tags = {
    Name = "GPU-Server IP"
  }
}

output "gpu_server_global_ips" {
  value = "${aws_instance.gpu_server.*.public_ip}"
  description = "The public IP address of the GPU server instances."
}

output "gpu_server_private_ips" {
  value = "${aws_instance.gpu_server.*.private_ip}"
  description = "The private IP address of the GPU server instances."
}
