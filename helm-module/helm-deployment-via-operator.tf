# Copyright (c) 2022, 2024 Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

resource "null_resource" "copy_chart_top_operator" {
  count = var.deploy_from_operator && var.helm_chart_path != "" ? 1 : 0

  triggers = {
    helm_chart_path = var.helm_chart_path
  }

  connection {
    bastion_host        = var.bastion_host
    bastion_user        = var.bastion_user
    bastion_private_key = var.ssh_private_key
    host                = var.operator_host
    user                = var.operator_user
    private_key         = var.ssh_private_key
    timeout             = "40m"
    type                = "ssh"
  }

  provisioner "remote-exec" {
    inline = [
      "rm -rf ${local.operator_helm_chart_path}",
      "mkdir -p ${local.operator_helm_charts_path}"
    ]
  }

  provisioner "file" {
    source      = var.helm_chart_path
    destination = local.operator_helm_chart_path
  }

  provisioner "file" {
    source      = var.kubectl_yaml_path
    destination = local.operator_kubectl_files_path
  }
}

resource "null_resource" "helm_deployment_via_operator" {
  count = var.deploy_from_operator ? 1 : 0

  triggers = {
    manifest_md5    = try(md5("${var.helm_template_values_override}-${var.helm_user_values_override}"), null)
    deployment_name = var.deployment_name
    namespace       = var.namespace
    bastion_host    = var.bastion_host
    bastion_user    = var.bastion_user
    ssh_private_key = var.ssh_private_key
    operator_host   = var.operator_host
    operator_user   = var.operator_user
  }

  connection {
    bastion_host        = self.triggers.bastion_host
    bastion_user        = self.triggers.bastion_user
    bastion_private_key = self.triggers.ssh_private_key
    host                = self.triggers.operator_host
    user                = self.triggers.operator_user
    private_key         = self.triggers.ssh_private_key
    timeout             = "40m"
    type                = "ssh"
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p ${local.operator_helm_values_path}"]
  }

  provisioner "file" {
    content     = var.helm_template_values_override
    destination = local.operator_helm_values_override_template_file_path
  }

  provisioner "file" {
    content     = var.helm_user_values_override
    destination = local.operator_helm_values_override_user_file_path
  }

  provisioner "remote-exec" {
    inline = concat(
      var.pre_deployment_commands,
      [
        "if [ -s \"${local.operator_helm_values_override_user_file_path}\" ]; then",
        join(" ", concat([
          "helm upgrade --install ${var.deployment_name}",
          "%{if var.helm_chart_path != ""}${local.operator_helm_chart_path}%{else}${var.helm_chart_name} --repo ${var.helm_repository_url}%{endif}",
          "--namespace ${var.namespace} --create-namespace --wait",
          "-f ${local.operator_helm_values_override_template_file_path}",
          "-f ${local.operator_helm_values_override_user_file_path}"
        ], var.deployment_extra_args)),
        "else",
        join(" ", concat([
          "helm upgrade --install ${var.deployment_name}",
          "%{if var.helm_chart_path != ""}${local.operator_helm_chart_path}%{else}${var.helm_chart_name} --repo ${var.helm_repository_url}%{endif}",
          "--namespace ${var.namespace} --create-namespace --wait",
          "-f ${local.operator_helm_values_override_template_file_path}"
        ], var.deployment_extra_args)),
        "fi"
      ],
      var.post_deployment_commands
    )

  }

  provisioner "remote-exec" {
    when       = destroy
    inline     = ["helm uninstall ${self.triggers.deployment_name} --namespace ${self.triggers.namespace} --wait"]
    on_failure = continue
  }

  lifecycle {
    ignore_changes = [
      triggers["bastion_host"],
      triggers["bastion_user"],
      triggers["ssh_private_key"],
      triggers["operator_host"],
      triggers["operator_user"]
    ]
  }

  depends_on = [null_resource.copy_chart_top_operator]
}