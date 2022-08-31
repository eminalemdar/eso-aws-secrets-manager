# External Secrets Operator with AWS Secrets Manager

This repository consists of example codes for installation of External Secrets Operator [(ESO)](https://external-secrets.io/) on an Amazon EKS Cluster and integration configurations with AWS Secrets Manager. ESO allows integrations with external Secret Management Providers and synchronize secrets into Kubernetes secret objects on your behalf from Kubernetes Clusters with simple Kubernetes YAML files.

## Prerequisites

- A Kubernetes Cluster

- AWS IAM Permissions for creating and attaching IAM Roles

- Installation of required tools:

  - [AWS CLI](https://aws.amazon.com/cli/)

  - [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

  - [Helm](https://helm.sh/docs/intro/install/)

  - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli#install-terraform)

  - [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)

If you don't have a Kubernetes cluster, you can create an EKS cluster with Terraform using the example codes within this repository.

## Terraform Codes

Terraform codes in this repository uses [Amazon EKS Blueprints for Terraform](https://aws-ia.github.io/terraform-aws-eks-blueprints/main/)

Terraform codes in this repository creates following resources:

- VPC with 6 subnets (3 Private, 3 Public)

- EKS Cluster with Kubernetes version set to 1.22

- EKS Managed Node group

- A secret resource on AWS Secrets Manager

> You can update the Terraform codes according to your requirements and environment.

### Installation of EKS Cluster

```shell
terraform init
terraform plan
terraform apply --auto-approve
```

> PS:
>
> - These resources are not Free Tier eligible.
> - You need to configure AWS Authentication for Terraform with either [Environment Variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-set) or AWS CLI [named profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html#cli-configure-profiles-create).

You can connect to your cluster using this command:

```bash
aws eks --region <region> update-kubeconfig --name <cluster_name>
```

> You need to change `region` and `cluster_name` parameters.

### Installation of External Secrets Operator

When you want to install External Secrets Operator and configure IAM Permissions you can run `./eso_install.sh`.

The [script](./eso_install.sh) has two functions called install_eso and permissions_eso.

- Install_eso function installs the required ESO Helm Chart to the Kubernetes cluster.

- Permissions_eso function creates OIDC identity provider for the Kubernetes cluster and creates IAM Roles for for Service Accounts of the ESO.

### Cleanup

When you want to delete all the resources created in this repository, you can run `./cleanup.sh` script in the root directory of this repository.

The [script](./cleanup.sh) has one function and does the following:

- Uninstalls the Helm Chart of ESO

- Deletes the IAM Roles and Policies

- Deletes the OIDC Provider of EKS Cluster

- Deletes the EKS Cluster created with Terraform
