output "eks_cluster_id" {
  value = aws_eks_cluster.gitops-cicd-demo.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.gitops-cicd-demo.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.gitops-cicd-demo.certificate_authority.0.data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.gitops-cicd-demo.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.cicd-node-group.id
}