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
Azure AI Foundry provides robust managed network isolation for its compute and Agent service. This is achieved by creating a managed Virtual Network (VNet) for the Foundry resource, utilizing private endpoints to securely connect to dependent Azure services. In the current **Foundry account + projects** model, the core agent dependencies are **Azure Storage, Azure AI Search, and Azure Cosmos DB**; Key Vault and Container Registry are dependencies of the classic Hub model and are optional in the account model.

### Key Features
- **Managed VNet**: Ensures compute resources are isolated from public networks.  
- **Private Endpoints**: Securely connect to core Azure services without exposing them to the internet.  
- **Outbound Modes**:  
  - **Allow Internet Outbound**: Unrestricted internet access for machine learning resources.  
  - **Allow Only Approved Outbound**: Restricts traffic to specified service tags, FQDNs, or private endpoints.  
  - **Disabled**: No isolation (not recommended for production environments).

> **2026 update — resource model**: The default Foundry resource is now an account (`Microsoft.CognitiveServices/accounts`) with **projects as sub-resources**, replacing the Azure Machine Learning–based **Hub** (now documented under *foundry-classic*). New accounts must be created with `customSubDomainName`, `allowProjectManagement`, and `networkInjections` set at creation time—these are immutable afterward.

## Prerequisites
Before deploying Azure AI Foundry with network isolation, ensure you have the following:  
- **Azure Subscription**: Active subscription with necessary permissions.  
- **Azure CLI**: Installed and configured on your machine.  
- **Networking Knowledge**: Familiarity with Azure VNets, subnets, and DNS configuration.  
- **Resource Group**: A dedicated resource group for deploying AI Foundry and network resources.
- **RBAC**: The **Foundry Account Owner** role at subscription scope to create the account/project, plus **Role Based Access Administrator** (or **Owner**) to assign roles on the BYO resources (Cosmos DB, AI Search, Storage). *Note: the Foundry roles were renamed from "Azure AI …" (for example, Azure AI Account Owner → Foundry Account Owner); the role IDs are unchanged.*
- **Registered resource providers**: `Microsoft.CognitiveServices`, `Microsoft.MachineLearningServices`, `Microsoft.Storage`, `Microsoft.Search`, `Microsoft.KeyVault`, `Microsoft.Network`, `Microsoft.App`, and `Microsoft.ContainerService` (add `Microsoft.Bing` for the Grounding with Bing tool).

## Configuring Managed Network for Azure AI Foundry

### Network Isolation Modes

> **2026 portal change**: When you create a **Foundry (account + project)** resource in the Azure portal today, the **Network** tab no longer shows the *"Allow Internet Outbound / Allow Only Approved Outbound / Disabled"* outbound dropdown. It now offers only:
> - **Public network access**: *Disabled* (recommended) or *Enabled*, plus an inbound **Private endpoint**.
> - **Outbound**: **Virtual network injection** — bring or create a VNet + a delegated subnet.
>
> The three outbound "modes" still exist, but only in the separate **managed virtual network** feature (a Microsoft-tenant VNet). They are **not** part of the Agent Service *Standard Setup with private networking* wizard the portal now surfaces.

There are two ways to network-isolate a Foundry account:

**Option A — Standard Setup with private networking (VNet injection) — current portal default**
- **Inbound**: public access **Disabled** + a **private endpoint** to the Foundry `account`.
- **Outbound**: **network injection** into *your* VNet via a subnet **delegated to `Microsoft.App/environments`** (recommended **/24**, minimum **/27**). By default there is **no public egress**.
- Uses **two subnets**: an **agent (runtime) subnet** (delegated) and a **private-endpoint subnet**. The agent subnet can't be shared across Foundry resources.
- Requires **bring-your-own** Storage, AI Search, and Cosmos DB (public access disabled, reached via private endpoints — these PEs are **not** auto-created; add them on each resource).
- Egress is controlled **on your own network** — see [Controlling agent egress (outbound rules)](#controlling-agent-egress-outbound-rules).

**Option B — Managed virtual network (Microsoft-managed)** — the classic three outbound modes:
- **Allow Internet Outbound**: unrestricted internet egress.
- **Allow Only Approved Outbound**: restricts egress to service tags, FQDN rules (ports 80/443, via a Microsoft-managed Azure Firewall), and private endpoints.
- **Disabled**: no managed isolation.

> **Note**: Outbound networking is immutable. With **injection** you can't change the delegated subnet after deployment; with a **managed VNet** you can't switch isolation mode. Either change requires redeploying Foundry.

### Controlling agent egress (outbound rules)
In the **VNet injection** model there is no "Allow Approved Outbound" toggle — you set outbound rules on **your own network**:

1. **Route the agent subnet through a firewall.** Attach a **route table (UDR)** to the delegated agent subnet: `0.0.0.0/0` → your **Azure Firewall** (or NVA) private IP. Typically the spoke VNet peers to a hub that hosts the firewall.
2. **Allowlist the required destinations on the firewall.** At minimum allow the **Managed Identity** FQDNs from [Integrate Azure Container Apps with Azure Firewall](https://learn.microsoft.com/azure/container-apps/use-azure-firewall#application-rules), **or** add the **`AzureActiveDirectory`** service tag (agent compute runs on the Container Apps environment your subnet is delegated to). Add application rules for every tool / API / package feed your agents call.
3. **Do not enable TLS inspection** on this traffic — a self-signed certificate breaks the agent control plane. If agents fail, inspect what the firewall is blocking.
4. **Public-endpoint tools** (Bing, Web Search, SharePoint) must be explicitly allowlisted or they will be blocked by the deny-by-default egress.

> With a **managed virtual network** (Option B) instead, you set "preferred outbound rules" as **user-defined outbound rules** (service tag / FQDN / private endpoint) directly in the Foundry networking blade, enforced by the Microsoft-managed firewall.

### Private DNS Zones
Private DNS zones are essential for resolving private endpoints within your VNet. The required zones depend on the Foundry resource model you use.

**Foundry (account + projects) model — current default** (`Microsoft.CognitiveServices/accounts`, private endpoint subresource `account`). The account exposes three FQDNs, so create and link all three zones:

- **privatelink.cognitiveservices.azure.com** — `{name}.cognitiveservices.azure.com`
- **privatelink.openai.azure.com** — `{name}.openai.azure.com`
- **privatelink.services.ai.azure.com** — `{name}.services.ai.azure.com`

**Hub-based model (classic)** — only if you deploy a classic Foundry Hub (Azure Machine Learning workspace lineage):

- **privatelink.api.azureml.ms**: Covers most AI Hub access.
- **privatelink.notebooks.azure.net**: Covers access to endpoints and compute instances.

> **Note**: If you upgrade from Azure OpenAI or a classic Hub to a Foundry account, you must recreate the private endpoint so the `services.ai.azure.com` and `cognitiveservices.azure.com` IP configurations are created.

### Network Connectivity Options
To connect your on-premises network to the Azure VNet containing the private endpoints, choose one of the following secure paths:

- **VPN Gateway**: Establishes a Site-to-Site VPN (IPsec) tunnel over the internet.
- **ExpressRoute**: Provides a private, dedicated fiber link with lower latency and higher reliability.

Ensure that DNS queries resolve to private endpoint IP addresses correctly by setting up Azure Private DNS Zones and configuring your on-premises DNS servers appropriately.

### Agent Tool Support in Network-Isolated Environments
When Foundry is network-isolated, agent tool support depends on the traffic path. This applies to Responses API agents created via SDK/CLI or the new Foundry portal.

| Tool | Status | Traffic path |
| --- | --- | --- |
| MCP Tool (private) | ✅ Supported | Your VNet subnet |
| OpenAPI tool | ✅ Supported | Your VNet subnet |
| Azure Functions | ✅ Supported | Your VNet subnet |
| Agent-to-Agent (A2A) | ✅ Supported | Your VNet subnet |
| Azure AI Search | ✅ Supported | Private endpoint |
| Function Calling | ✅ Supported | Microsoft backbone |
| Code Interpreter | ⚠️ Partial | Microsoft backbone (no file upload/download; use SDK `container_id` workaround) |
| Bing Grounding / Web Search / SharePoint | ✅ Supported | Public endpoint (egress leaves your private network) |
| Foundry IQ (preview) | ✅ Supported | Via MCP |
| Fabric Data Agent | ❌ Not supported | Requires public network access |
| Logic Apps, File Search, Browser Automation, Computer Use, Image Generation | ❌ Not supported | Under development |

> **Note**: Public-endpoint tools (Bing, Web Search, SharePoint) work behind a VNet but communicate over the public internet. Block them with Azure Policy if your compliance requires all traffic to stay private.

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

### 17. Configure Private DNS Zones for Foundry endpoints
For the Foundry account model, create the three private DNS zones that back the account's FQDNs and let the private endpoint register its records automatically:

- **privatelink.cognitiveservices.azure.com**
- **privatelink.openai.azure.com**
- **privatelink.services.ai.azure.com**

```bash
# Example: Create the three Foundry account private DNS zones
for zone in privatelink.cognitiveservices.azure.com privatelink.openai.azure.com privatelink.services.ai.azure.com; do
  az network private-dns zone create \
    --resource-group CustomerNetworkRG \
    --name "$zone"
done
```

> For the classic Hub model, use `privatelink.api.azureml.ms` and `privatelink.notebooks.azure.net` instead.

### 18. Link Virtual Networks to DNS Zones
Link your customer VNet to each private DNS zone to ensure correct DNS resolution.

```bash
for zone in privatelink.cognitiveservices.azure.com privatelink.openai.azure.com privatelink.services.ai.azure.com; do
  az network private-dns link vnet create \
    --resource-group CustomerNetworkRG \
    --zone-name "$zone" \
    --vnet-name CustomerVNet \
    --name "Link-${zone}" \
    --registration-enabled false
done
```
> **Note**: If creating a new project/account using the same private DNS zones, link the zones to the new VNet here.

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

## Simplifying RBAC Configuration with Bicep

To simplify the RBAC configuration required for both Azure AI Foundry services and users accessing resources from a private VNet, use the provided Bicep template (`main.bicep`) and its corresponding parameters file (`parameters.json`). These scripts automate the assignment of necessary RBAC roles, ensuring secure and streamlined access management.

### Deploying RBAC Configuration using Bicep

1. **Review and update parameters** in `parameters.json` with your specific resource names and principal IDs:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "aiSearchName": { "value": "<your-ai-search-service-name>" },
    "aiOpenAIName": {
      "value": "<your-openai-service-name>"
    },
    "storageAccountName": {
      "value": "<your-storage-account-name>"
    },
    "blobPrivateEndpointName": {
      "value": "<your-blob-private-endpoint-name>"
    },
    "aiSearchPrincipalId": {
      "value": "<principal-id-of-ai-search-service>"
    },
    "aiOpenAIPrincipalId": {
      "value": "<principal-id-of-ai-openai-service>"
    },
    "developerPrincipalId": {
      "value": "<developer-azure-ad-object-id>"
    },
    "storageAccountName2": {
      "value": "<your-second-storage-account-name>"
    },
    "developerPrincipalId": {
      "value": "<developer-azure-ad-object-id>"
    }
}
```

### Deploying the Bicep Template

Deploy the provided `main.bicep` template using Azure CLI:

```bash
az deployment group create \
  --resource-group CustomerNetworkRG \
  --template-file main.bicep \
  --parameters @parameters.json
```

This deployment will automatically configure the necessary RBAC roles for:

- Azure AI Foundry services (AI Search, OpenAI, Storage Accounts)
- Developers and users accessing AI Foundry resources securely from the private VNet

The provided Bicep template assigns roles such as:

- **Search Index Data Contributor**
- **Search Index Data Reader**
- **Cognitive Services Contributor**
- **Storage Blob Data Contributor**
- **Storage File Data Privileged Contributor**

These assignments ensure secure and simplified access management aligned with Azure best practices.

> **Managed private endpoints (account model)**: To let the Foundry account auto-approve managed private endpoints to your resources, assign the **Azure AI Enterprise Network Connection Approver** role (`b556d68e-0be0-4f35-a333-ad7ee1ce17ea`) to the account's system-assigned managed identity at the scope of the target resources (Storage, AI Search, Cosmos DB).

> **Note**: Ensure all principal IDs and resource names in `parameters.json` match your Azure environment before deployment.

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
- **Use Private Endpoints**: For all supported resources (Storage, AI Search, Cosmos DB, Key Vault, ACR, etc.) to ensure secure connectivity. Note that **managed** private endpoints in the Foundry managed VNet are fully Microsoft-managed and do **not** create a customer-visible NIC or subnet entry.
- **Whitelist Strictly**: Only add necessary service tags or FQDN rules to minimize exposure. Note that FQDN rules permit only HTTP/S traffic and may incur additional costs via Azure Firewall.
- **Register Providers**: Ensure that the Microsoft.Network provider is registered in your Azure subscription.
- **Role Assignments**: Pre-assign necessary RBAC roles to streamline deployment.
- **Early Testing**: Provision network resources early to identify and resolve connectivity issues promptly.

## Limitations
- **Immutable Network Isolation Mode**: Once a network isolation mode is selected and the hub is deployed, it cannot be changed. To switch modes, you must delete and redeploy the AI Foundry hub.
- **AI Agents in a VNet**: The Foundry Agent Service now **supports network isolation** (managed VNet and VNet injection). Tool support varies by traffic path—see [Agent Tool Support in Network-Isolated Environments](#agent-tool-support-in-network-isolated-environments). For configuration details, see [How to configure network isolation for Microsoft Foundry](https://learn.microsoft.com/azure/foundry/how-to/configure-private-link).
- **Private ACR for hosted agents**: Foundry projects created after **June 25, 2026** support a private (network-secured) Azure Container Registry with public access disabled and a private endpoint. Projects created before that date require the registry to be reachable over its public endpoint.
- **Delegated agent subnet**: The runtime subnet must be delegated to `Microsoft.App/environments`, sized **/27 or larger** (**/24 recommended**), use an RFC1918 range (`10/8`, `172.16-31/12`, `192.168/16` — no CGNAT `100.64/10`), and **cannot be shared** by more than one Foundry resource.
- **Same region**: The Foundry account must be in the **same region as the VNet**. Dependent Storage/Search/Cosmos DB may live in other regions (at cross-region cost).
- **No TLS inspection on agent egress**: A firewall that injects a self-signed certificate breaks the agent control plane; allowlist by FQDN/service tag instead.
- **Managed VNet Deletion**: Deleting the AI Foundry hub will also delete the managed VNet, potentially impacting connected resources.
- **Setup Time**: To expedite setup, manually provision network resources or deploy a compute instance early in the deployment process.
- **Connectivity Testing**: Always verify connectivity post-setup to ensure all required resources are accessible under the chosen isolation mode.

## References
- [Set up private networking for Foundry Agent Service (VNet injection — current portal flow)](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks)
- [Deep dive into Foundry Agent Service networking](https://learn.microsoft.com/azure/foundry/agents/concepts/agents-networking-deep-dive)
- [Integrate Azure Container Apps with Azure Firewall (agent egress FQDN allowlist)](https://learn.microsoft.com/azure/container-apps/use-azure-firewall)
- [Configure managed virtual network for Microsoft Foundry (managed-VNet outbound modes)](https://learn.microsoft.com/azure/foundry/how-to/managed-virtual-network)
- [Configure network isolation (private link) for Microsoft Foundry](https://learn.microsoft.com/azure/foundry/how-to/configure-private-link)
- [Azure Private Endpoint private DNS zone values](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)
- [Upgrade from Azure OpenAI to Microsoft Foundry — private network configuration](https://learn.microsoft.com/azure/foundry/how-to/upgrade-azure-openai#private-network-configuration)
- [Foundry hub & project (classic) networking](https://learn.microsoft.com/azure/foundry-classic/how-to/hub-configure-private-link)
- [AVM module: avm/ptn/ai-ml/ai-foundry](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/ai-ml/ai-foundry)
- Azure ExpressRoute
- Azure Firewall
- Secure Data Playground with Entra

This README provides a comprehensive guide to deploying Azure AI Foundry with managed network isolation. By following these steps, you can ensure a secure and well-configured environment tailored to your organization's needs.