
############# TASK 1 ####################

# vpc
resource "aws_vpc" "development" {
  cidr_block       = "10.120.0.0/16"
  instance_tenancy = "default"
}

# Internet gateway
resource "aws_internet_gateway" "development-ig" {
  vpc_id = aws_vpc.development.id
}

# elastic IP
resource "aws_eip" "nat-eip" {
  vpc = true
}

# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

# subent 
resource "aws_subnet" "development-public-1a" {
  vpc_id            = aws_vpc.development.id
  cidr_block        = "10.120.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "development-public-1b" {
  vpc_id            = aws_vpc.development.id
  cidr_block        = "10.120.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_subnet" "development-private-1a" {
  vpc_id            = aws_vpc.development.id
  cidr_block        = "10.120.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

# nat gateway
resource "aws_nat_gateway" "development-nat" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.development-public-1a.id
  depends_on    = [aws_internet_gateway.development-ig]
}


# route tables
resource "aws_route_table" "development-public" {
  vpc_id = aws_vpc.development.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.development-ig.id
  }
}

resource "aws_route_table" "development-private" {
  vpc_id = aws_vpc.development.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.development-nat.id
  }
}

# Subnet association
resource "aws_route_table_association" "arta1" {
  subnet_id      = aws_subnet.development-public-1a.id
  route_table_id = aws_route_table.development-public.id
}

resource "aws_route_table_association" "arta2" {
  subnet_id      = aws_subnet.development-public-1b.id
  route_table_id = aws_route_table.development-public.id
}

resource "aws_route_table_association" "arta3" {
  subnet_id      = aws_subnet.development-private-1a.id
  route_table_id = aws_route_table.development-private.id
}

# role
resource "aws_iam_role" "s3_role" {
  name = "s3_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "profile" {
  name = "profile"
  role = aws_iam_role.s3_role.name
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "s3_policy"
  role = aws_iam_role.s3_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# access key
resource "aws_key_pair" "ssh" {
  key_name   = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC9fBHzj/vQDLPIkC4eFBTZaG+/Cg6sm7wAIsJMpwom+RqMSPJH9BYJONjF2QGnyd8MGA8Lz4unFljryh3fQjc2OZj2oKd44L0NVPC+Lms+fBfTNvK4DBCaqPxFZfAjWRZOATS6aPPmu3kW8/lY4A+U1tx2NTY/JTu2XwItdl1r7dw9YxRRpnWkl1mOOM2oKM/YH50+Sprqi+RVJq/uZwAmAxQosgedW49fcWvuPc1WMrZohMgTFRGYuv7mIL0wirWS51+7Ct5ZYJcaR3YyNT/p/L7OksdjL0o4+4zuaOO+e4LTzTJERXEO09eMhJSW7jbPpClZ/dQzDggxVqhlref9vvrLEmsywrS0JE8/bH0sApOFKiCwW4joWigikuY2I2kUVxIvoitOcHVRkMeFSEQvlirf+loErZcYyHRfH5DN3AVzK1B80KqQ5SS81oJFoVr7eEiVzCfxmXwwXMnU/kd6m+ZsJBo24h2ZIbWhQPeiIQ9NuVVEPEIhra4j8O9uCpk= ayushverma@Ayushs-MacBook-Pro.local"
}

# security group for ec2
resource "aws_security_group" "dev-ec2-sg" {
  vpc_id = aws_vpc.development.id
  name   = "dev-ec2-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb-sg" {
  vpc_id = aws_vpc.development.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create instance
resource "aws_instance" "development-ec2" {
  ami                    = "ami-0f40c8f97004632f9"
  subnet_id              = aws_subnet.development-private-1a.id
  key_name               = aws_key_pair.ssh.key_name
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.dev-ec2-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.profile.name
  #   user_data = << EOF 
  #         #! /bin/bash
  #         sudo apt-get update
  #         sudo apt-get install -y apache2
  #         sudo systemctl start apache2
  #         sudo systemctl enable apache2
  #         echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
  # 	EOF
  user_data = file("install_apache.sh")
}

# Create a new load balancer
resource "aws_elb" "development-lb" {
  name            = "development-lb"
  subnets         = [aws_subnet.development-public-1a.id, aws_subnet.development-public-1b.id]
  security_groups = [aws_security_group.elb-sg.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

  instances                   = [aws_instance.development-ec2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

}




########### TASK 3 ############


resource "aws_ami_from_instance" "development-ami" {
  name               = "development-ami"
  source_instance_id = aws_instance.development-ec2.id
}

## Creating Launch Configuration
resource "aws_launch_configuration" "development-lc" {
  image_id             = aws_ami_from_instance.development-ami.id
  instance_type        = aws_instance.development-ec2.instance_type
  security_groups      = [aws_security_group.dev-ec2-sg.id]
  key_name             = aws_key_pair.ssh.key_name
  iam_instance_profile = aws_iam_instance_profile.profile.name
  lifecycle {
    create_before_destroy = true
  }
}


## Creating AutoScaling Group
resource "aws_autoscaling_group" "development-ag" {
  name                 = "development-ag"
  launch_configuration = aws_launch_configuration.development-lc.id
  vpc_zone_identifier = [
    aws_subnet.development-public-1a.id,
    aws_subnet.development-public-1b.id
  ]
  load_balancers    = [aws_elb.development-lb.name]
  health_check_type = "ELB"
  min_size          = 1
  max_size          = 3
  desired_capacity  = 1
}

# auto scaliung policies
resource "aws_autoscaling_policy" "development-ag-scale-up" {
  name                   = "development-ag-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.development-ag.name
}

resource "aws_autoscaling_policy" "development-ag-scale-down" {
  name                   = "development-ag-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.development-ag.name
}

# cloud watch metrics
resource "aws_cloudwatch_metric_alarm" "cpu-high" {
  alarm_name          = "cpu-util-high-development-ag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 CPU for high utilization on EC2"
  alarm_actions = [
    aws_autoscaling_policy.development-ag-scale-up.arn
  ]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.development-ag.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu-low" {
  alarm_name          = "cpu-util-low-development-ag"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "60"
  alarm_description   = "This metric monitors ec2 CPU for low utilization on EC2"
  alarm_actions = [
    aws_autoscaling_policy.development-ag-scale-down.arn
  ]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.development-ag.name
  }
}