# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  deploy_from_operator = var.create_operator_and_bastion
  deploy_from_local    = alltrue([!local.deploy_from_operator, var.control_plane_is_public])
}

data "oci_containerengine_cluster_kube_config" "kube_config" {
  count = local.deploy_from_local ? 1 : 0

  cluster_id = module.oke.cluster_id
  endpoint   = "PUBLIC_ENDPOINT"
}


module "kuberay-operator" {
  count  = var.deploy_kuberay_operator ? 1 : 0
  source = "./helm-module"

  bastion_host    = module.oke.bastion_public_ip
  bastion_user    = var.bastion_user
  operator_host   = module.oke.operator_private_ip
  operator_user   = var.bastion_user
  ssh_private_key = tls_private_key.stack_key.private_key_openssh

  deploy_from_operator = local.deploy_from_operator
  deploy_from_local    = local.deploy_from_local

  deployment_name     = "kuberay-operator"
  helm_chart_name     = "kuberay-operator"
  namespace           = "kuberay-operator"
  helm_repository_url = "https://ray-project.github.io/kuberay-helm/"

  pre_deployment_commands  = []
  post_deployment_commands = []

  kubectl_yaml_path = ""

  helm_template_values_override = templatefile(
    "${path.root}/helm-values-templates/kuberay-operator-values.yaml.tpl",{}
  )
  helm_user_values_override = try(base64decode(var.kuberay_operator_user_values_override), var.kuberay_operator_user_values_override)

  kube_config = one(data.oci_containerengine_cluster_kube_config.kube_config.*.content)
  depends_on  = [module.oke]
}

module "kueue" {
  source = "./helm-module"

  bastion_host    = module.oke.bastion_public_ip
  bastion_user    = var.bastion_user
  operator_host   = module.oke.operator_private_ip
  operator_user   = var.bastion_user
  ssh_private_key = tls_private_key.stack_key.private_key_openssh

  deploy_from_operator = local.deploy_from_operator
  deploy_from_local    = local.deploy_from_local
  deployment_name     = "kueue"
  helm_chart_name     = "kueue"
  namespace           = "kueue-system"
  helm_chart_path     = "./helm-kueue"

  pre_deployment_commands  = []
  post_deployment_commands = [
    local.deploy_from_operator ? "kubectl apply -f /home/${var.operator_user}/kubectl-files/kueue-resources-priorityscheduling.yaml" : "kubectl apply -f ${path.root}/generated/kubectl-files/kueue-resources-priorityscheduling.yaml",
    "kubectl create namespace team-a",  
    "kubectl create namespace team-b",
    local.deploy_from_operator ? "kubectl apply -f /home/${var.operator_user}/kubectl-files/cq-team-a.yaml" : "kubectl apply -f ${path.root}/generated/kubectl-files/cq-team-a.yaml",
    local.deploy_from_operator ? "kubectl apply -f /home/${var.operator_user}/kubectl-files/cq-team-b.yaml" : "kubectl apply -f ${path.root}/generated/kubectl-files/cq-team-b.yaml"
  ]

  kubectl_yaml_path = "${path.root}/kubectl-files"
  

  # this override the values.yaml file from chart
  # this is a file present in helm-values-templates folder
  helm_template_values_override = templatefile(
    "${path.root}/helm-values-templates/kueue-values.yaml.tpl",{}
  )

  # this is a file user uploads from ORM 
  helm_user_values_override = try(base64decode(var.kueue_user_values_override), var.kueue_user_values_override)

  kube_config = one(data.oci_containerengine_cluster_kube_config.kube_config.*.content)
  depends_on  = [module.kuberay-operator]
}
