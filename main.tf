provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

resource "aws_iam_role" "cicd-cluster" {
  name               = local.cluster_name
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cicd-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cicd-cluster.name
}

resource "aws_security_group" "cicd-cluster" {
  name   = local.cluster_name
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gitops-cicd-demo"
  }
}

resource "aws_eks_cluster" "gitops-cicd-demo" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cicd-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.cicd-cluster.id]
    subnet_ids     = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.cicd-cluster-AmazonEKSClusterPolicy
  ]
}

resource "aws_iam_role" "cicd-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cicd-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.cicd-node.name
}

resource "aws_iam_role_policy_attachment" "cicd-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.cicd-node.name
}

resource "aws_iam_role_policy_attachment" "cicd-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.cicd-node.name
}

resource "aws_eks_node_group" "cicd-node-group" {
  cluster_name    = aws_eks_cluster.gitops-cicd-demo.name
  node_group_name = "microservices"
  node_role_arn   = aws_iam_role.cicd-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.cicd-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.cicd-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.cicd-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG_END
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.gitops-cicd-demo.certificate_authority.0.data}
    server: ${aws_eks_cluster.gitops-cicd-demo.endpoint}
  name: ${aws_eks_cluster.gitops-cicd-demo.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.gitops-cicd-demo.arn}
    user: ${aws_eks_cluster.gitops-cicd-demo.arn}
  name: ${aws_eks_cluster.gitops-cicd-demo.arn}
current-context: ${aws_eks_cluster.gitops-cicd-demo.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.gitops-cicd-demo.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.gitops-cicd-demo.name}"
    KUBECONFIG_END
  filename = "kubeconfig"
}