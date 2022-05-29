provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "eu-west-1"
}

resource "aws_instance" "gpu_server" {
    # ami in region (eu-west-1) - Deep Learning AMI (Ubuntu 18.04) Version 60.4
    ami = "ami-07afb32b4cb2c5c44" # the ami-id depends on your region
    instance_type = "g3s.xlarge"
    key_name = "aws_andrej_key"
    vpc_security_group_ids = [aws_security_group.main.id]

    provisioner "remote-exec" {
      inline = [
        "touch hello.txt",
        "echo helloworld remote provisioner >> hello.txt",
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
      private_key = file("/Users/andrej/.ssh/aws_andrej_key")
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
  key_name   = "aws_andrej_key"
  public_key = "${var.ssh_public_key}"
}
