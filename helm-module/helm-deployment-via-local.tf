# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "local_file" "helm_template_file" {
  count = var.deploy_from_local ? 1 : 0

  content  = var.helm_template_values_override
  filename = local.local_helm_values_override_template_file_path
}


resource "local_file" "helm_user_file" {
  count = var.deploy_from_local ? 1 : 0

  content  = var.helm_user_values_override
  filename = local.local_helm_values_override_user_file_path
}

resource "local_file" "cluster_kube_config_file" {
  count = var.deploy_from_local ? 1 : 0

  content  = var.kube_config
  filename = local.local_kubeconfig_path
}

resource "local_file" "kubectl_files" {
  for_each = var.deploy_from_local && var.kubectl_yaml_path != "" ? fileset(var.kubectl_yaml_path, "*") : []
  source   = "${var.kubectl_yaml_path}/${each.value}"
  filename = "${local.local_kubectl_files_path}/${each.value}"
}

resource "null_resource" "helm_deployment_from_local" {
  count = var.deploy_from_local ? 1 : 0

  triggers = {
    manifest_md5    = try(md5("${var.helm_template_values_override}-${var.helm_user_values_override}"), null)
    deployment_name = var.deployment_name
    namespace       = var.namespace
    kube_config     = var.kube_config
  }

  provisioner "local-exec" {
    working_dir = path.root
    command     = <<-EOT
      export KUBECONFIG=${local.local_kubeconfig_path}
      ${join("\n", var.pre_deployment_commands)}
      if [ -s "${local.local_helm_values_override_user_file_path}" ]; then
      echo ""
      echo "Terraform generated values:"
      cat "${local.local_helm_values_override_template_file_path}"
      echo ""
      echo "User provided values:"
      cat "${local.local_helm_values_override_user_file_path}"
      echo ""
      helm upgrade --install ${var.deployment_name} \
      %{if var.helm_chart_path != ""}${var.helm_chart_path}%{else}${var.helm_chart_name} --repo ${var.helm_repository_url}%{endif} \
      --namespace ${var.namespace} \
      --create-namespace --wait \
      -f ${local.local_helm_values_override_template_file_path} \
      -f ${local.local_helm_values_override_user_file_path} ${join(" ", var.deployment_extra_args)}
      else
      echo ""
      echo "Terraform generated values:"
      cat "${local.local_helm_values_override_template_file_path}"
      echo ""
      helm upgrade --install ${var.deployment_name} \
      %{if var.helm_chart_path != ""}${var.helm_chart_path}%{else}${var.helm_chart_name} --repo ${var.helm_repository_url}%{endif} \
      --namespace ${var.namespace} \
      --create-namespace --wait \
      -f ${local.local_helm_values_override_template_file_path} ${join(" ", var.deployment_extra_args)}
      fi
      ${join("\n", var.post_deployment_commands)}
      EOT
  }

  # This provisioner is not executed when the resource is commented out: https://github.com/hashicorp/terraform/issues/25073 
  provisioner "local-exec" {
    when = destroy
    environment = {
      kube_config = self.triggers.kube_config
    }
    working_dir = path.root
    command     = <<-EOT
      mkdir -p ./generated; \
      echo "$kube_config" > ./generated/kubeconfig-${self.triggers.namespace}-${self.triggers.deployment_name}-on-destroy; \
      export KUBECONFIG=./generated/kubeconfig-${self.triggers.namespace}-${self.triggers.deployment_name}-on-destroy; \
      helm uninstall ${self.triggers.deployment_name} --namespace ${self.triggers.namespace} --wait; \
      rm ./generated/kubeconfig-${self.triggers.namespace}-${self.triggers.deployment_name}-on-destroy
      EOT
    on_failure  = continue
  }
  lifecycle {
    ignore_changes = [
      triggers["local_kubeconfig_path"]
    ]
  }

  depends_on = [local_file.cluster_kube_config_file, local_file.kubectl_files, local_file.helm_template_file, local_file.helm_user_file]
}