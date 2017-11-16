# Provider details

provider "aws" {
  region = "eu-west-2"
}

data "aws_availability_zones" "all" {}

#Auto scaling group configuration

resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = 1
  max_size = 2

  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
  }
}

#Launch configuration details

resource "aws_launch_configuration" "example" {
  image_id = "ami-ecbea388"
  instance_type = "t2.micro"
  key_name = "mykey"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get remove docker docker-engine docker.io
              sudo apt-get update
              sudo apt-get install -y \
              linux-image-extra-$(uname -r | sed 's/-aws$//') \
              linux-image-extra-virtual
              sudo apt-get update
              sudo apt-get install -y \
              apt-transport-https \
              ca-certificates \
              curl \
              software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo apt-key fingerprint 0EBFCD88
              sudo add-apt-repository \
              "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) \
              stable"
              sudo apt-get update
              sudo apt-get install -y docker-ce
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

#Security group setup

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port = 22
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

#Elastic Load Balancer setup

resource "aws_elb" "example" {
  name = "terraform-asg-example"
  security_groups = ["${aws_security_group.elb.id}"]
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  health_check {
    healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:80/"
  }
  listener {
    lb_port = 80
        lb_protocol = "http"
        instance_port = 22
        instance_protocol = "http"
  }
}

#Security group for elb

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
