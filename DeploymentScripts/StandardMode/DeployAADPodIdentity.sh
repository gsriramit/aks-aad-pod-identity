#!/bin/bash

export SUBSCRIPTION_ID=""
RESOURCEGROUP_LOCATION="EastUS"
RESOURCEGROUP_NAME="rg-akspodidentity-dev-01"
CLUSTER_NAME="aks-dev-01"
export IDENTITY_NAME="podidentity-test"

# login as a user and set the appropriate subscription ID
az login
az account set -s "${SUBSCRIPTION_ID}"

# install the needed features
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.OperationalInsights
az feature register --name EnablePodIdentityPreview --namespace Microsoft.ContainerService

# Install the aks-preview extension
az extension add --name aks-preview

# create the base resource group
az group create --location $RESOURCEGROUP_LOCATION --name $RESOURCEGROUP_NAME --subscription $SUBSCRIPTION_ID 

# Create an RBAC enabled AKS cluster
az aks create -g $RESOURCEGROUP_NAME -n $CLUSTER_NAME --enable-aad --enable-azure-rbac --enable-pod-identity --network-plugin azure --node-count 1 --enable-addons monitoring

# for this demo, we will be deploying a user-assigned identity to the AKS node resource group
export IDENTITY_RESOURCE_GROUP="$(az aks show -g ${RESOURCEGROUP_NAME} -n ${CLUSTER_NAME} --query nodeResourceGroup -otsv)"

# get the client-Id of the managed identity assigned to the node pool
AGENTPOOL_IDENTITY_CLIENTID=$(az aks show -g $RESOURCEGROUP_NAME -n $CLUSTER_NAME --query identityProfile.kubeletidentity.clientId -o tsv)

# perform the necessary role assignments to the managed identity of the nodepool (used by the kubelet)
# Important Note: The roles Managed Identity Operator and Virtual Machine Contributor must be assigned to the cluster managed identity or service principal, identified by the ID obtained above, 
# ""before deploying AAD Pod Identity"" so that it can assign and un-assign identities from the underlying VM/VMSS.
az role assignment create --role "Managed Identity Operator" --assignee $AGENTPOOL_IDENTITY_CLIENTID --scope /subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}
az role assignment create --role "Virtual Machine Contributor" --assignee $AGENTPOOL_IDENTITY_CLIENTID --scope /subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}

# get the cluster access credentials before executing the K8s API commands
# Note: the --admin switch is optional and not adviced for production setups
az aks get-credentials -n aks-dev-01 -g rg-akspodidentity-dev-01 --admin

# Test if the manual installation of these CRDs are necessary
# The manifests are downlaoded from the azure github repo
kubectl apply -f ../PodIdentityManifests/deployment-rbac.yaml
# For AKS clusters, deploy the MIC and AKS add-on exception by running -
kubectl apply -f ../PodIdentityManifests/mic-exception.yaml

# Create the managed (user-assigned) identity that will be assigned to the pods (in a specific namespace if required) to authenticate with AAD and access azure resources 
az identity create -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME}
export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query clientId -otsv)"
export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query id -otsv)"

# Note: The following K8s manifests can be deployed to the cluster using the file as i/p param after the needed values are updated
# The Yq tool can be used to achieve this - https://github.com/mikefarah/yq

# Create the needed "AzureIdentity" resource kind
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: ${IDENTITY_NAME}
spec:
  type: 0
  resourceID: ${IDENTITY_RESOURCE_ID}
  clientID: ${IDENTITY_CLIENT_ID}
EOF

# Create the needed "AzureIdentityBinding" resource kind- this lets the NMI pods to communicate with the IMDS
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: ${IDENTITY_NAME}-binding
spec:
  azureIdentity: ${IDENTITY_NAME}
  selector: ${IDENTITY_NAME}
EOF

# Create the test workload pods that will be assigned the Pod-Managed-Identity
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: $IDENTITY_NAME
spec:
  containers:
  - name: demo
    image: mcr.microsoft.com/oss/azure/aad-pod-identity/demo:v1.8.4
    args:
      - --subscription-id=${SUBSCRIPTION_ID}
      - --resource-group=${IDENTITY_RESOURCE_GROUP}
      - --identity-client-id=${IDENTITY_CLIENT_ID}
  nodeSelector:
    kubernetes.io/os: linux
EOF