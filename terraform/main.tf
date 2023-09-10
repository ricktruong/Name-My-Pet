provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "Name-My-Pet"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${local.cluster_name}-VPC"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_dns_hostnames = true

  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.public_subnets
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {

    one = {
      name = "ng-1-app"

      instance_types = ["t2.medium"]

      min_size     = 0
      max_size     = 2
      desired_size = 1

      capacity_type = "SPOT"

      vpc_security_group_ids = [aws_security_group.nodeport-sg.id]
    }
  }
}

# NodePort security group
resource "aws_security_group" "nodeport-sg" {
  name        = "nodeport-sg"
  description = "NodePort - Allow inbound TCP traffic on port 31479"
  vpc_id      = module.vpc.vpc_id

  # NodePort security group inbound rule
  ingress {
    description = "HTTPS ingress"
    from_port   = 31479
    to_port     = 31479
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NodePort security group rule - attach to cluster's primary security group
# resource "aws_security_group_rule" "sg-nodeport" {
#   type              = "ingress"
#   from_port         = 31479
#   to_port           = 31479
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = module.eks.cluster_primary_security_group_id  # Attach this NodePort ingress sg rule to the sg with this id
# }


# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.20.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}