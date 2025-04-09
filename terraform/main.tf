provider "aws" {
  region = "us-east-1"  # Change to your preferred region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "laravel-vpc"
  }
}

# Create two public subnets
resource "aws_subnet" "public" {
  count = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "laravel-public-subnet-${count.index}"
    "kubernetes.io/cluster/laravel-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }
}

data "aws_availability_zones" "available" {}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "laravel-igw"
  }
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "laravel-public-rt"
  }
}

# Associate route table with subnets
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# IAM role for EKS
resource "aws_iam_role" "eks_cluster" {
  name = "laravel-eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# Create EKS cluster
resource "aws_eks_cluster" "main" {
  name     = "laravel-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  
  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# IAM role for EKS nodes
resource "aws_iam_role" "eks_nodes" {
  name = "laravel-eks-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# Create EKS node group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "laravel-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.public[*].id
  instance_types  = ["t3.small"]  # Free tier eligible instance type
  
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only
  ]
}

# Create ECR repository for Docker images
resource "aws_ecr_repository" "app" {
  name = "laravel-app"
}

# Output the key information
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "kubeconfig_update_command" {
  value = "aws eks update-kubeconfig --region us-east-1 --name laravel-cluster"
}