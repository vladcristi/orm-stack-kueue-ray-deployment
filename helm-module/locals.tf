# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

locals {
  helm_values_override_user_file     = "${var.namespace}-${var.deployment_name}-user-values-override.yaml"
  helm_values_override_template_file = "${var.namespace}-${var.deployment_name}-template-values-override.yaml"



  operator_helm_values_path = coalesce(var.operator_helm_values_path, "/home/${var.operator_user}/tf-helm-values")
  operator_helm_charts_path = coalesce(var.operator_helm_charts_path, "/home/${var.operator_user}/tf-helm-charts")

  operator_helm_chart_path    = "${local.operator_helm_charts_path}/${var.namespace}-${var.deployment_name}-${basename(var.helm_chart_path)}"
 
  operator_helm_values_override_user_file_path     = join("/", [local.operator_helm_values_path, local.helm_values_override_user_file])
  operator_helm_values_override_template_file_path = join("/", [local.operator_helm_values_path, local.helm_values_override_template_file])

  operator_kubectl_files_path = coalesce(var.operator_kubectl_files_path, "/home/${var.operator_user}/")



  local_helm_values_override_user_file_path     = join("/", [path.root, "generated", local.helm_values_override_user_file])
  local_helm_values_override_template_file_path = join("/", [path.root, "generated", local.helm_values_override_template_file])

  local_kubeconfig_path = "${path.root}/generated/kubeconfig-${var.namespace}-${var.deployment_name}"

  local_kubectl_files_path    = join("/", [path.root, "generated", trim(var.kubectl_yaml_path, "./")])
}