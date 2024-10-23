# ORM Stack: Deploying and Configuring Kueue and Kuberay in OKE with Full Infrastructure Setup


## Description
This terraform stack deploys:
   - full infrastructure setup like networking, bastion, operator, policies for operator if needed
   - an OKE cluster with two node pools:
        1. Generic instances node pool
        2. GPU instances node pool
   - Kueue in kueue-system namespace of the cluster
   - Kuberay-Operator in kuberay-operator namespace of the cluster


This terraform stack configures:
   - initial setup of kueue resources that will be used for examples in quota management and priority scheduling in OKE

## Usage
Once uploaded in Oracle Resource Manager:
1. You will select the compartment where you want to deploy the infrastructure, and the cluster name. Also you will be able to set advanced OKE settings like Kubernetes version and cluster networking type
2. You can select if you want to create a new VCN for the OKE or you want to use an existing vcn. Recommended: use the option to create a new VCN which will have you in place all the networking configuration needed.
3. You can select how many generic nodes will have in the first nodepool with some configuration options, and how many gpu nodes will have the second nodepool with some configuration options. Recommended: keep the default configuration provided for the scope of the example.
4. You can select if you want to create a bastion and operator to interact with the cluster, or if you think you would need to create opeartor IAM policy, or if you want to create public OKE API based on your preference. After that you will be required to provide a ssh public key that will be in the ~/.ssh/authorized_keys file for the bastion, operator and worker nodes.
5. You will see the section where it tells what helm chart will deploy. And you will the Kueue and Kuberay Operator helm charts are ticked to deploy in the OKE cluster.


After you upload the ORM stack with the fields where you are required to provide input, you will do an apply and wait for the apply job to run the terraform code which will bring up the infrastructure and configuration.

