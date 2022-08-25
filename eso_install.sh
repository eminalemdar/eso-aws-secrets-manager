#!/bin/bash
: '
The following script has two functions with different actions
Install function installs the required Helm Chart
for the External Secrets Operator
on the Kubernetes cluster.
Permissions function creates required IRSA config
and configures required IAM Permissions for the 
ESO and connects that to the
service account.
'

echo "===================================================="
echo "Creating required Environment Variables."
echo "===================================================="

declare AWS_REGION="eu-west-1"
declare EKS_CLUSTER_NAME="eso-demo"
declare ESO_SYSTEM_NAMESPACE="external-secrets"

install(){
  
  # Setting the Environment variables for Service Controller Helm Chart
  declare -i HELM_EXPERIMENTAL_OCI=1 # Only required for Helm below v3.8.0

  echo "===================================================="
  echo "Installing the ESO Helm Chart."
  echo "===================================================="

  helm repo add external-secrets https://charts.external-secrets.io

  helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true
}

#####################################################################################################################
#####################################################################################################################

permissions(){

  echo "===================================================="
  echo "Creating IRSA for EKS Cluster"
  echo "===================================================="

  ###########################################################
  # You can skip this step if you have already configured   #
  # IRSA for your Kubernetes Cluster.                       #
  ###########################################################
  
  eksctl utils associate-iam-oidc-provider --cluster ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --approve

  echo "===================================================="
  echo "Creating Service Account"
  echo "===================================================="

  # Setting the required parameters for OIDC Provider.
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
  OIDC_PROVIDER=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

  ESO_K8S_SERVICE_ACCOUNT_NAME="eso-sa"

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ESO_K8S_SERVICE_ACCOUNT_NAME}
  namespace: ${ESO_SYSTEM_NAMESPACE}
EOF

  echo "===================================================="
  echo "Creating Required IAM Role and Policy"
  echo "===================================================="

  # Creating IAM Trust Policy. 
  read -r -d '' TRUST_RELATIONSHIP <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "${OIDC_PROVIDER}:sub": "system:serviceaccount:${ESO_SYSTEM_NAMESPACE}:${ESO_K8S_SERVICE_ACCOUNT_NAME}"
          }
        }
      }
    ]
  }
EOF
  echo "${TRUST_RELATIONSHIP}" > trust.json
  
  # Setting the required Environment Variables for IRSA (IAM Roles for Service Accounts).
  ESO_IAM_ROLE="eso-iam-role"
  ESO_IAM_ROLE_DESCRIPTION='IRSA role for External Secrets Operator deployment on EKS cluster using Helm charts'

  aws iam create-role --role-name "${ESO_IAM_ROLE}" --assume-role-policy-document file://trust.json --description "${ESO_IAM_ROLE_DESCRIPTION}"

  ESO_IAM_ROLE_ARN=$(aws iam get-role --role-name=${ESO_IAM_ROLE} --query Role.Arn --output text)

  SECRETS_MANAGER_ARN=$(terraform output -raw secrets_manager_arn)
  KMS_KEY_ARN=$(terraform output -raw kms_key_arn)

  read -r -d '' SECRET_STORE_POLICY <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        "Resource": "${SECRETS_MANAGER_ARN}"
      },
      {
        "Effect": "Allow",
        "Action": [
          "kms:Decrypt"
        ],
        "Resource": "${KMS_KEY_ARN}"
      }
    ]
  }
POLICY
  echo "${SECRET_STORE_POLICY}" > policy.json
  
  ESO_IAM_POLICY="eso_secrets_manager_policy"
  aws iam create-policy --policy-name "${ESO_IAM_POLICY}" --policy-document file://policy.json 

  POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${ESO_IAM_POLICY}"

  # Attaching the policy to the IAM Role.
  while IFS= read -r POLICY_ARN; do
      echo -n "Attaching ${POLICY_ARN} ... "
      aws iam attach-role-policy \
          --role-name "${ESO_IAM_ROLE}" \
          --policy-arn "${POLICY_ARN}"
      echo "ok."
  done

  echo "===================================================="
  echo "Associating the Role with the Service Account"
  echo "===================================================="

  # Updating the Kubernetes Service Account with the new IAM Role
  declare IRSA_ROLE_ARN=eks.amazonaws.com/role-arn=${ESO_IAM_ROLE_ARN}
  kubectl annotate serviceaccount -n ${ESO_SYSTEM_NAMESPACE} ${ESO_K8S_SERVICE_ACCOUNT_NAME} ${IRSA_ROLE_ARN}

}

install
permissions