# Azure AI Foundry Networking Isolation Mode

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Configuring Managed Network for Azure AI Foundry](#configuring-managed-network-for-azure-ai-foundry)
4. [Network Isolation Modes](#network-isolation-modes)
5. [Private DNS Zones](#private-dns-zones)
6. [Network Connectivity Options](#network-connectivity-options)
7. [Step‑by‑Step Deployment Guide](#step-by-step-deployment-guide)
8. [Summary](#summary)
9. [Best Practices](#best-practices)
10. [Limitations](#limitations)
11. [References](#references)

## Overview
Azure AI Foundry provides robust managed network isolation for its compute resources, including compute instances, serverless functions, and online endpoints. This is achieved by creating a managed Virtual Network (VNet) for the AI Foundry hub, utilizing private endpoints to securely connect to essential Azure services such as Storage, Key Vault, and Container Registry.

### Key Features
- **Managed VNet**: Ensures compute resources are isolated from public networks.  
- **Private Endpoints**: Securely connect to core Azure services without exposing them to the internet.  
- **Outbound Modes**:  
  - **Allow Internet Outbound**: Unrestricted internet access for machine learning resources.  
  - **Allow Only Approved Outbound**: Restricts traffic to specified service tags, FQDNs, or private endpoints.  
  - **Disabled**: No isolation (not recommended for production environments).

## Prerequisites
Before deploying Azure AI Foundry with network isolation, ensure you have the following:  
- **Azure Subscription**: Active subscription with necessary permissions.  
- **Azure CLI**: Installed and configured on your machine.  
- **Networking Knowledge**: Familiarity with Azure VNets, subnets, and DNS configuration.  
- **Resource Group**: A dedicated resource group for deploying AI Foundry and network resources.

## Configuring Managed Network for Azure AI Foundry

### Network Isolation Modes
Azure AI Foundry offers three outbound network isolation modes within its managed VNet:

- **Allow Internet Outbound**: Enables unrestricted internet access for ML resources.
- **Allow Only Approved Outbound**: Restricts outbound traffic to specified service tags, Fully Qualified Domain Names (FQDNs), or private endpoints.
- **Disabled**: No network isolation (not recommended).

> **Note**: Once a network isolation mode is selected and the hub is deployed, switching to another mode requires redeploying the hub.

### Private DNS Zones
Private DNS zones are essential for resolving private endpoints within your VNet. Azure AI Foundry creates two private DNS zones:

- **privatelink-api-azureml-ms**: Covers most AI Hub access.
- **privatelink-notebooks-azure-net**: Covers access to endpoints and compute instances.

### Network Connectivity Options
To connect your on-premises network to the Azure VNet containing the private endpoints, choose one of the following secure paths:

- **VPN Gateway**: Establishes a Site-to-Site VPN (IPsec) tunnel over the internet.
- **ExpressRoute**: Provides a private, dedicated fiber link with lower latency and higher reliability.

Ensure that DNS queries resolve to private endpoint IP addresses correctly by setting up Azure Private DNS Zones and configuring your on-premises DNS servers appropriately.

## Step-by-Step Deployment Guide

### Scenario 1 & 2: Allow Outbound / Allow Approved Outbound
This guide covers deploying Azure AI Foundry with both **"Allow Internet Outbound"** and **"Allow Only Approved Outbound"** modes, focusing on disabling public access for the hub and accessing it from both an Azure VM within the VNet and from an on-premises network.

### 1. Set Up Customer Network Resource Group
Create a dedicated resource group for your customer network:

```bash
az group create --name CustomerNetworkRG --location eastus
```

### 2. Create Customer Virtual Network (VNet)
Set up the VNet with a private IP range unlikely to collide with Azure service ranges:

- **Address Space**: `10.100.0.0/16`
- **Reason**: Common private IP range with sufficient flexibility.

```bash
az network vnet create \
  --resource-group CustomerNetworkRG \
  --name CustomerVNet \
  --address-prefix 10.100.0.0/16 \
  --subnet-name CustomerWorkloadsSubnet \
  --subnet-prefix 10.100.1.0/24
```

### 3. Create Required Subnets  
Ensure the VNet has at least three subnets:  
- **Customer Workloads**: `10.100.1.0/24`  
- **GatewaySubnet**: `10.100.254.0/27`  
- **DNS Forwarder Subnet (Optional)**: 10.100.2.0/24  

#### Example: Create GatewaySubnet
```bash
az network vnet subnet create \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --name GatewaySubnet \
  --address-prefix 10.100.254.0/27
```

#### Example: Create DNS Forwarder Subnet (Optional)
```bash
az network vnet subnet create \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --name DNSForwarderSubnet \
  --address-prefix 10.100.2.0/24
```

### 4. Deploy Azure AI Foundry Service
Deploy the Azure AI Foundry service, selecting to create a new Storage Account (SA) and Azure Container Registry (ACR). Note that **Premium ACR** is required.

```bash
az ai-foundry create \
  --name AIFoundryHub \
  --resource-group CustomerNetworkRG \
  --location eastus \
  --storage-account-name aifoundrysa \
  --container-registry-name aifoundryacr \
  --sku Premium
```

### 5. Configure Private Endpoints for AI Hub
For inbound access, create a Private Endpoint (PE) for the AI Hub projected into the customer VNet.

```bash
az network private-endpoint create \
  --name PE-AIFoundryHub \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <AI_HUB_RESOURCE_ID> \
  --group-ids api \
  --connection-name AIFoundryHubConnection
```

### 6. Select Network Isolation Mode
During deployment, choose the network isolation mode:  
- **Allow Only Approved Outbound**: This setting restricts outbound traffic, enhancing security by limiting data exfiltration.

### 7. Manage Outbound Rules
Expand the required outbound rules, emphasizing that these are compute outbound rules. By default, all other outbound access is blocked as part of the Azure managed VNet.

- **Observation**:
  - Outbound rules are initially in the **Inactive** state.
  - They become **Active** once compute resources are created in the hub, avoiding unnecessary costs.
  - Rules define destinations such as Key Vault (KV), Azure Container Registry (ACR), Storage Account (SA), etc.

- **Customization**: Define additional rules, e.g., allowing access to specific Python package repositories.

### 8. Enable Default Encryption
Ensure that default encryption is enabled to protect data at rest and in transit within the network.

### 9. Configure Access Credentials
Initially, maintain credential-based access for Storage Account (SA) access. Plans to transition to Entra-based authentication will be executed in subsequent steps.

### 10. Deploy and Validate Hub Accessibility
Deploy the AI Foundry hub and verify that it cannot be accessed from outside the VNet.

### 11. Verify Network Isolation Settings
Navigate to AI Foundry Networking and confirm that **Allow Approved Outbound Only** is enabled while other options are disabled.

> **Important**: Once deployed with this setting, you cannot switch to other outbound modes without redeploying the hub.

### 12. Secure Additional Deployed Resources
Review all other deployed resources to ensure they have public access disabled one by one.

### 13. Configure AI Services Private Endpoints
Disable public access for AI services and create private endpoints as needed.

```bash
az network private-endpoint create \
  --name PE-AIService \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <AI_SERVICE_RESOURCE_ID> \
  --group-ids aiService \
  --connection-name AIServiceConnection
```

### 14. Secure Storage Accounts (SA)
Disable public access for Storage Accounts:

First, enable public access for the Customer VNet.
Then, disable it.
Create Private Endpoints for each resource type (Blob, File).
```bash
# Disable public access
az storage account update \
  --name aifoundrysa \
  --resource-group CustomerNetworkRG \
  --allow-public-access false
```
Create Private Endpoints for Blob and File services:

```bash
az network private-endpoint create \
  --name PE-SA-Blob \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <SA_RESOURCE_ID> \
  --group-ids blob \
  --connection-name SABlobConnection

az network private-endpoint create \
  --name PE-SA-File \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <SA_RESOURCE_ID> \
  --group-ids file \
  --connection-name SAFileConnection
```

### 15. Secure Key Vault (KV)
Repeat the Storage Account steps for Key Vault:

Disable public access.
Create Private Endpoints.
```bash
# Disable public access for KV
az keyvault update \
  --name aifoundrykv \
  --resource-group CustomerNetworkRG \
  --public-network-access Disabled

# Create Private Endpoint for KV
az network private-endpoint create \
  --name PE-KV \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <KV_RESOURCE_ID> \
  --group-ids vault \
  --connection-name KVConnection
```

### 16. Secure Container Registry (ACR)
Secure ACR by disabling public access and creating a Private Endpoint.

```bash
# Disable public access for ACR
az acr update \
  --name aifoundryacr \
  --resource-group CustomerNetworkRG \
  --public-network-enabled false

# Create Private Endpoint for ACR
az network private-endpoint create \
  --name PE-ACR \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <ACR_RESOURCE_ID> \
  --group-ids registry \
  --connection-name ACRConnection
```

### 17. Configure Private DNS Zones for OpenAI
Azure AI Foundry creates multiple DNS records for OpenAI endpoints:

- Inference Endpoint
- Model Endpoint (for MaaS deployments)
- ML Workspace
- ML Workspace Certificate

All records are managed under the same private link.

```bash
# Example: Configure Private DNS Zone for OpenAI Inference Endpoint
az network private-dns record-set a add-record \
  --resource-group CustomerNetworkRG \
  --zone-name privatelink-api-azureml-ms \
  --record-set-name inference.openai \
  --ipv4-address <PRIVATE_IP>
```

### 18. Link Virtual Networks to DNS Zones
Link your customer VNet to the private DNS zones to ensure correct DNS resolution.

```bash
az network private-dns link vnet create \
  --resource-group CustomerNetworkRG \
  --zone-name privatelink-api-azureml-ms \
  --vnet-name CustomerVNet \
  --name LinkToCustomerVNet \
  --registration-enabled false
```
> **Note**: If creating a new hub using the same private DNS zone, link the DNS zone to the new VNet here.

### 19. Access Foundry from a Virtual Machine
Create a VM within the customer VNet and access the AI Foundry hub via Azure Bastion.

```bash
az vm create \
  --resource-group CustomerNetworkRG \
  --name FoundryAccessVM \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --image UbuntuLTS \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-address ""  # No public IP for enhanced security
```
Access via Bastion: Use Azure Bastion to securely connect to the VM without exposing it to the internet.

### 20. Provision Compute Instances
From the AI Foundry hub, provision compute instances with advanced configurations:

- **User Assignment**: Assign compute instances to dedicated users if others won't use them.
- **Managed Network Isolation**: Azure deploys an Azure Firewall in the background, denying all outbound access unless explicitly whitelisted via FQDNs.

```yaml
# Example: YAML Configuration for Compute Instance
compute:
  type: aml.compute
  properties:
    isolation_mode: "AllowApprovedOutbound"
    user_assignment:
      - user: dedicated_user@example.com
```

### 21. Manage Projects and Deployments
Within the Foundry hub:

- **Create a Project**: Projects are created as workspaces within the hub and receive a CNAME in the hub’s private DNS zone.
- **Deploy a Model**: Create deployments and interact with them via the playground.

```bash
# Example: Create a Project via CLI
az ai-foundry project create --name MyProject --hub-name AIFoundryHub
```
- **DNS Validation**: If a VM fails to deploy in due time, use nslookup to verify DNS resolution to the hub’s private endpoint.

```bash
nslookup openai.endpoint.aifoundryhub.privatelink-api-azureml-ms
```

### 22. Validate DNS Resolution
Ensure that DNS queries resolve to the hub's private endpoint:

```bash
nslookup <FQDN_of_OpenAI_Endpoint>
```
- **Expected Output**: The FQDN should resolve to the private IP address of the hub’s Private Endpoint.

### 23. Verify Active Outbound Rules
After compute instances are deployed, confirm that all outbound rules are set to Active in the network configuration.

### 24. Bring Your Own Data (BYOD) Integration
Deploy a Cognitive Service and Storage Account (SA) to hold customer data:

- **Disable Public Access**.
- **Create Private Endpoints** projected into both the customer VNet and the hub VNet.

```bash
# Example: Deploy Cognitive Service with Private Endpoint
az cognitive-services account create \
  --name AIFoundryCognitiveService \
  --resource-group CustomerNetworkRG \
  --kind OpenAI \
  --sku S0 \
  --location eastus \
  --yes

az network private-endpoint create \
  --name PE-CognitiveService \
  --resource-group CustomerNetworkRG \
  --vnet-name CustomerVNet \
  --subnet CustomerWorkloadsSubnet \
  --private-connection-resource-id <Cognitive_Service_RESOURCE_ID> \
  --group-ids cognitiveServices \
  --connection-name CognitiveServiceConnection
```
- **Connect Resources**: Add deployed Cognitive Services and SA as Connected Resources in Foundry Hub and Foundry Project, respectively.

### 25. Switch to Entra-Based Authentication
Transition from credential-based access to Microsoft Entra (formerly Azure AD) based authentication for enhanced security.

#### Steps:

- **Assign Roles**: Assign necessary RBAC roles to hub users and system-managed identities for connected resources.

- **Enable Managed Identity for Services**: For AI Search and AI Services, switch managed identity ON.

```bash
az search update \
  --name AIFoundrySearch \
  --resource-group CustomerNetworkRG \
  --set identity.type=SystemAssigned
```

- **Configure API Access**: Ensure API Access is set to Both for services like AI Search.

- **Assign Storage Account Roles**: Add the Storage File Data Contributor role to allow functionalities like Prompt Flow or VSCode integration.

- **Update Project Instances**: Create data and index instances, uploading data to customer SA as needed.

- **Troubleshooting**: If index creation fails due to outbound access, add a new outbound rule for the AI Services Private Endpoint.

```bash
# Example: Add Outbound Rule via Azure Firewall
az network firewall network-rule create \
  --firewall-name AIFoundryFirewall \
  --resource-group CustomerNetworkRG \
  --collection-name AllowAIService \
  --name AllowOpenAIOutbound \
  --protocols TCP \
  --source-addresses 10.100.1.0/24 \
  --destination-fqdns openai.azure.com \
  --destination-ports 443 \
  --action Allow
```

## Summary
- **Network Isolation**: Azure AI Foundry’s managed VNet isolates the hub’s compute resources from public networks. It connects to Azure services via private endpoints, ensuring secure communication.

- **Outbound Modes**:

  - **Allow Internet Outbound**: Full internet access.
  - **Allow Only Approved Outbound**: Controlled egress traffic based on whitelist rules.
  - **Disabled**: No isolation (requires redeployment for changes).

- **Setup Flexibility**: Configuration can be achieved via:

  - Azure Portal
  - Azure CLI
  - Python SDK (MLClient)

- **Key parameters**:

  - CLI: --managed-network
  - SDK/YAML: isolation_mode

## Best Practices
- **Use Private Endpoints**: For all supported resources (Storage, Key Vault, ACR, etc.) to ensure secure connectivity.
- **Whitelist Strictly**: Only add necessary service tags or FQDN rules to minimize exposure. Note that FQDN rules permit only HTTP/S traffic and may incur additional costs via Azure Firewall.
- **Register Providers**: Ensure that the Microsoft.Network provider is registered in your Azure subscription.
- **Role Assignments**: Pre-assign necessary RBAC roles to streamline deployment.
- **Early Testing**: Provision network resources early to identify and resolve connectivity issues promptly.

## Limitations
- **Immutable Network Isolation Mode**: Once a network isolation mode is selected and the hub is deployed, it cannot be changed. To switch modes, you must delete and redeploy the AI Foundry hub.
- **Managed VNet Deletion**: Deleting the AI Foundry hub will also delete the managed VNet, potentially impacting connected resources.
- **Setup Time**: To expedite setup, manually provision network resources or deploy a compute instance early in the deployment process.
- **Connectivity Testing**: Always verify connectivity post-setup to ensure all required resources are accessible under the chosen isolation mode.

## References
- Azure AI Foundry Documentation
- Configuring Managed VNet for AI Foundry
- Azure Private DNS Zones
- Azure ExpressRoute
- Azure Firewall
- Secure Data Playground with Entra

This README provides a comprehensive guide to deploying Azure AI Foundry with managed network isolation. By following these steps, you can ensure a secure and well-configured environment tailored to your organization's needs.