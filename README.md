# AKS AAD-POD-IDENTITY
This repository contains scripts and instructions to perform a quick deployment and validation of Managed &amp; Standard modes of AAD Pod Managed Identities in AKS. Please note that we do not try to duplicate the content available as a part of the standard Walkthrough of Pod Managed Identitities at https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/ but elaborate the process with output dumps and a detailed flow diagram

## Pod Identity- Flow Diagram

![Security Baseline Architecture - Pod Managed Identity-Flow Diagram](https://user-images.githubusercontent.com/13979783/155840253-13cc3e0b-872d-4868-9081-09b555520cd2.png)

## Deployment Scripts
1. [Standard Mode](DeploymentScripts/StandardMode/DeployAADPodIdentity.sh)
2. MangedMode - To be implemented

## Output Dump

Assignment of the "Managed Identity Operator" role to the Agent Pool ClientID
```
srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity$ az role assignment create --role "Managed Identity Operator" --assignee $AGENTPOOL_IDENTITY_CLIENTID --scope /subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}
{
  "canDelegate": null,
  "condition": null,
  "conditionVersion": null,
  "description": null,
  "id": "/subscriptions/<subscriptionId>/resourcegroups/MC_rg-akspodidentity-dev-01_aks-dev-01_eastus/providers/Microsoft.Authorization/roleAssignments/9416fc6b-d401-41ff-b08a-e76b96aac5ec",
  "name": "9416fc6b-d401-41ff-b08a-e76b96aac5ec",
  "principalId": "<ServicePrincipalId>",
  "principalType": "ServicePrincipal",
  "resourceGroup": "MC_rg-akspodidentity-dev-01_aks-dev-01_eastus",
  "roleDefinitionId": "/subscriptions/<subscriptionId>/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830",
  "scope": "/subscriptions/<subscriptionId>/resourcegroups/MC_rg-akspodidentity-dev-01_aks-dev-01_eastus",
  "type": "Microsoft.Authorization/roleAssignments"
}
```
Assignment of the Virtual Machine Contributor role to the AgentPool ClientID
```
srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity$ az role assignment create --role "Virtual Machine Contributor" --assignee $AGENTPOOL_IDENTITY_CLIENTID --scope /subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${IDENTITY_RESOURCE_GROUP}
{
  "canDelegate": null,
  "condition": null,
  "conditionVersion": null,
  "description": null,
  "id": "/subscriptions/<subscriptionId>/resourcegroups/MC_rg-akspodidentity-dev-01_aks-dev-01_eastus/providers/Microsoft.Authorization/roleAssignments/13621784-cd28-47d0-9749-11efd9a30e55",
  "name": "13621784-cd28-47d0-9749-11efd9a30e55",
  "principalId": "<ServicePrincipalId>",
  "principalType": "ServicePrincipal",
  "resourceGroup": "MC_rg-akspodidentity-dev-01_aks-dev-01_eastus",
  "roleDefinitionId": "/subscriptions/<subscriptionId>/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c",
  "scope": "/subscriptions/<subscriptionId>/resourcegroups/MC_rg-akspodidentity-dev-01_aks-dev-01_eastus",
  "type": "Microsoft.Authorization/roleAssignments"
}
```
Deployment of the NMI and MIC CRDs. This step is applicable only for the Standard mode. In the Managed Mode, AKS would have these CRDs deployed into the newly created AKS cluster. 

```
srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl apply -f PodIdentityManifests/deployment-rbac.yaml
serviceaccount/aad-pod-id-nmi-service-account created
customresourcedefinition.apiextensions.k8s.io/azureassignedidentities.aadpodidentity.k8s.io created
customresourcedefinition.apiextensions.k8s.io/azureidentities.aadpodidentity.k8s.io created
customresourcedefinition.apiextensions.k8s.io/azureidentitybindings.aadpodidentity.k8s.io created
customresourcedefinition.apiextensions.k8s.io/azurepodidentityexceptions.aadpodidentity.k8s.io created
clusterrole.rbac.authorization.k8s.io/aad-pod-id-nmi-role created
clusterrolebinding.rbac.authorization.k8s.io/aad-pod-id-nmi-binding created
daemonset.apps/nmi created
serviceaccount/aad-pod-id-mic-service-account created
clusterrole.rbac.authorization.k8s.io/aad-pod-id-mic-role created
clusterrolebinding.rbac.authorization.k8s.io/aad-pod-id-mic-binding created
deployment.apps/mic created
```

Explicit deployment of the Exceptions targetting the NMI pods.  
```
srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl apply -f PodIdentityManifests/mic-exception.yaml
azurepodidentityexception.aadpodidentity.k8s.io/mic-exception created
azurepodidentityexception.aadpodidentity.k8s.io/aks-addon-exception created
```

Pods deployed to the targeted or the default namespace after the installation of the CRDs
```
# this should be the list of pods after the installation of the NMI and MIC components
srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl get pods
NAME                  READY   STATUS    RESTARTS   AGE
mic-d8455d95c-5k59g   1/1     Running   0          107s
mic-d8455d95c-k4z7r   1/1     Running   0          107s
nmi-x9d8l             1/1     Running   0          109s
```
Creation of the User-Assigned Managed Identity that will be used by the pods to perform authN and authz with the azure resources
```

srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ az identity create -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME}
{
  "clientId": "Redacted",
  "clientSecretUrl": "Redacted",
  "id": "/subscriptions/<SubscriptionId>/resourcegroups/MC_rg-akspodidentity-dev-01_aks-dev-01_eastus/providers/Microsoft.ManagedIdentity/userAssignedIdentities/podidentity-test",
  "location": "eastus",
  "name": "podidentity-test",
  "principalId": "Redacted,
  "resourceGroup": "MC_rg-akspodidentity-dev-01_aks-dev-01_eastus",
  "tags": {},
  "tenantId": "<tenantId>",
  "type": "Microsoft.ManagedIdentity/userAssignedIdentities"
}

srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl get AzureIdentity
NAME               TYPE   CLIENTID                               AGE
podidentity-test   0      731fe34e-05a6-470e-9334-929bfae0f97f   13s

srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl get AzureIdentityBinding
NAME                       AZUREIDENTITY      SELECTOR           AGE
podidentity-test-binding   podidentity-test   podidentity-test   34s

srvadmin@DESKTOP-LP3ON48:/mnt/c/DevApplications/KubernetesPlayground/aks-aad-pod-identity/DeploymentScripts$ kubectl logs demo
I0217 02:42:53.895859       1 main.go:75] successfully acquired a service principal token from http://169.254.169.254/metadata/identity/oauth2/token
I0217 02:42:53.907371       1 main.go:100] successfully acquired a service principal token from http://169.254.169.254/metadata/identity/oauth2/token using a user-assigned identity (731fe34e-05a6-470e-9334-929bfae0f97f)
```

## References
1. Official MS documentation - https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity
2. Official GitHub Repo - https://github.com/Azure/aad-pod-identity#demo
3. Standard Walkthrough - https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/
4. Underlying concepts -  https://azure.github.io/aad-pod-identity/docs/concepts/


