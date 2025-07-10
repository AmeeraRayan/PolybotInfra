resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ameera-k8s-vpc-${var.env}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "ameera-igw-${var.env}"
  }
}
# IAM Role for control plane EC2 instance
resource "aws_iam_role" "control_plane_role" {
  name = "ameera-k8s-control-plane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}


# Attach necessary policies to the control plane IAM role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "secrets_manager_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
# Instance profile for EC2
resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "ameera-k8s-control-plane-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "ameera-k8s-worker-profile"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.k8s_vpc.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "ameera-public-subnet-${count.index}-${var.env}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "ameera-public-rt-${var.env}"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg-${var.env}"
  description = "Allow SSH, Kubernetes API, and internal VPC traffic"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "SSH from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kubernetes API traffic"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the VPC"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow all traffic within the VPC"
    from_port   = 32533
    to_port     = 32533
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ameera-control-plane-sg-${var.env}"
  }
}

resource "aws_instance" "control_plane" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.control_plane_sg.id]

  user_data = file("${path.module}/user_data_control_plane.sh")
  iam_instance_profile = aws_iam_instance_profile.control_plane_profile.name

  tags = {
    Name = "ameera-k8s-control-plane"
  }
}

resource "aws_eip" "control_plane_eip" {
  instance = aws_instance.control_plane.id

  tags = {
    Name = "ameera-control-plane-eip-${var.env}"
  }
}

resource "aws_security_group" "worker_sg" {
  name        = "worker-sg-${var.env}"
  description = "Allow traffic for worker nodes"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your IP for better security
  }

  ingress {
    description = "Allow all traffic to kubelet "
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with your IP for better security
  }

  ingress {
    description = "Allow all traffic from within VPC"
    from_port   = 32533
    to_port     = 32533
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

   ingress {
    description = "Allow NodePort range"
    from_port   = 30630
    to_port     = 30630
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]

  }

  ingress {
    description = "Allow NodePort range"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/16"]

  }
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ameera-worker-sg-${var.env}"
  }
}


resource "aws_iam_role_policy_attachment" "worker_s3_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "worker_dynamodb_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "worker_sqs_access" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_launch_template" "worker_lt" {
  name_prefix   = "k8s-worker-${var.env}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.worker_sg.id]
  }

  user_data = base64encode(file("${path.module}/user_data_worker.sh"))

  block_device_mappings {
    device_name = "/dev/sda1" # This is usually the root device on Amazon Linux/Ubuntu
    ebs {
      volume_size = 20        # 🔥 Set root volume size to 20 GiB
      volume_type = "gp3"     # or "gp2"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "k8s-worker-${var.env}"
    }
  }
}

resource "aws_autoscaling_group" "worker_asg" {
  name                      = "k8s-worker-asg-${var.env}"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "k8s-worker-${var.env}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_target_group" "telegram_target_group" {
  name        = "telegram-target-group-${var.env}"
  port        = 30630                           # NodePort of your ingress-nginx
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.k8s_vpc.id

  health_check {
    path                = "/healthz"
    port                = "30630"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tg-${var.env}"
  }
}

resource "aws_lb" "telegram_alb" {
  name               = "telegram-alb-${var.env}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "telegram-alb-${var.env}"
  }
}


resource "aws_security_group" "lb_sg" {
  name   = "lb-sg-${var.env}"
  vpc_id = aws_vpc.k8s_vpc.id

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb-sg-${var.env}"
  }
}

resource "aws_security_group_rule" "allow_worker_to_worker_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.worker_sg.id
  source_security_group_id = aws_security_group.worker_sg.id
  description       = "Allow all traffic between worker nodes"
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.telegram_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.telegram_target_group.arn
  }
}

resource "aws_autoscaling_attachment" "asg_target_group_attachment" {
  autoscaling_group_name = aws_autoscaling_group.worker_asg.name
  lb_target_group_arn    = aws_lb_target_group.telegram_target_group.arn
}