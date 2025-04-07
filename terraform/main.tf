provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "laravel-eks-cluster"
  cluster_version = "1.25"
  subnet_ids      = ["subnet-abc123", "subnet-def456"] # Replace these
  vpc_id          = "vpc-xyz789" # Replace this
}
