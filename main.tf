# Define your provider and region
provider "aws" {
  region = "us-west-2"  # Replace with your desired region
}

# Create a VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

# Create subnets
resource "aws_subnet" "eks_subnet" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"  # Replace with your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet"
  }
}

# Create security group
resource "aws_security_group" "eks_sg" {
  vpc_id = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "eks-security-group"
  }
}

# Create IAM roles
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# Create EKS cluster
resource "aws_eks_cluster" "eks_cluster" {
  name               = "eks-cluster"
  role_arn           = aws_iam_role.eks_cluster_role.arn
  version            = "1.21"  # Replace with your desired EKS version
  vpc_config {
    subnet_ids         = [aws_subnet.eks_subnet.id]
    security_group_ids = [aws_security_group.eks_sg.id]
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  tags = {
    Name = "eks-cluster"
  }
}

# Create IAM OpenID Connect (OIDC) provider
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url                = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
  client_id_list     = ["sts.amazonaws.com"]
  thumbprint_list    = aws_eks_cluster.eks_cluster.identity.0.oidc.0.thumbprint_list
}

