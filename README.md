# AI Foundry Enterprise-Grade Deployment: Private Networking Architecture

This README provides a comprehensive technical overview of deploying Azure AI Foundry in an enterprise-grade environment with a focus on private networking, security, and compliance. It synthesizes Microsoft documentation and the provided architecture diagram (`ai-foundry-infra-networking.drawio`).

---

## Table of Contents
- [Overview](#overview)
- [Network Isolation Architecture](#network-isolation-architecture)
- [Key Components & Layers](#key-components--layers)
- [Network Isolation Modes](#network-isolation-modes)
- [Private Endpoints & Service Access](#private-endpoints--service-access)
- [Outbound Rules & Azure Firewall](#outbound-rules--azure-firewall)
- [On-Premises & Hybrid Connectivity](#on-premises--hybrid-connectivity)
- [Security, Compliance, and Best Practices](#security-compliance-and-best-practices)
- [References](#references)

---

## Overview
Azure AI Foundry enables secure, scalable, and compliant AI workloads in the cloud. In an enterprise context, it is critical to ensure that all compute and data resources are isolated from the public internet, accessible only via private networking, and governed by strict access controls. This repository includes a diagram (`ai-foundry-infra-networking.drawio`) that visualizes the recommended architecture for such deployments.

---

## Network Isolation Architecture
When deploying AI Foundry with managed network isolation:
- A managed virtual network (VNet) is automatically created for the hub.
- All compute resources (instances, clusters, endpoints) are deployed into this VNet.
- Private endpoints are used for all Azure dependencies (Storage, Key Vault, Container Registry, etc.), ensuring no public exposure.
- Outbound traffic is tightly controlled via Azure Firewall and user-defined rules.

Refer to the diagram for a visual breakdown of these layers and their relationships.

---

## Key Components & Layers
- **Models, Embeddings, Prompt Flow, Vector DB, Managed Endpoints, WebApp**: Each component is deployed in isolated subnets within the managed VNet, with access governed by Network Security Groups (NSGs).
- **BYO VNET vs Managed VNET**: AI Foundry supports only managed VNets for compute isolation. However, you can connect your on-premises or other Azure VNets to the managed VNet for hybrid scenarios.
- **Private Endpoints**: Used for all supported Azure services (see below).
- **Firewall & NAT Gateway**: All outbound traffic is routed through Azure Firewall (if FQDN rules are used) and NAT Gateway for egress control and monitoring.

---

## Network Isolation Modes
AI Foundry supports two main isolation modes:

### 1. Allow Internet Outbound
- Outbound traffic to the internet is allowed.
- Private endpoints are still used for Azure resources.
- Use this mode if you require access to public ML resources (e.g., Python packages).

### 2. Allow Only Approved Outbound
- Outbound traffic is denied by default; only explicitly approved destinations are allowed.
- Approvals can be for Private Endpoints, Service Tags, or FQDNs (the latter requires Azure Firewall).
- Strongest data exfiltration protection; recommended for high-security environments.

> **Note:** Once managed network isolation is enabled, it cannot be disabled.

---

## Private Endpoints & Service Access
Private endpoints are supported for:
- Azure AI Foundry hub
- Azure AI Search
- Azure AI services
- Azure API Management
- Azure Container Registry
- Azure Cosmos DB
- Azure Data Factory
- Azure Database for MariaDB/MySQL/PostgreSQL
- Azure Databricks
- Azure Event Hubs
- Azure Key Vault
- Azure Machine Learning
- Azure Redis Cache
- Azure SQL Server
- Azure Storage

All critical dependencies should be accessed via private endpoints. Resources can be in different subscriptions but must be in the same tenant.

---

## Outbound Rules & Azure Firewall
- **Required Outbound Rules**: Service tags for AzureMachineLearning, AzureActiveDirectory, BatchNodeManagement, AzureResourceManager, AzureFrontDoor, MicrosoftContainerRegistry, AzureMonitor, and VirtualNetwork are automatically added.
- **Scenario-Specific Rules**: For public package repositories (e.g., PyPI, Anaconda), VS Code integration, or HuggingFace models, add FQDN rules as needed.
- **Azure Firewall**: Deployed automatically if FQDN rules are used in "Allow Only Approved Outbound" mode. Choose Standard or Basic SKU as appropriate.
- **NAT Gateway**: Used for static outbound IP and egress control.

---

## On-Premises & Hybrid Connectivity
- **VPN/ExpressRoute**: Connect on-premises networks to the managed VNet for secure hybrid scenarios.
- **Private DNS Zones**: Required for name resolution of private endpoints.
- **Accessing Private Storage**: When using private storage accounts, access must originate from within the VNet.

---

## Security, Compliance, and Best Practices
- Use "Allow Only Approved Outbound" for maximum security.
- Always use private endpoints for Azure dependencies.
- Restrict NSG rules to the minimum required.
- Monitor and log all network activity with Azure Monitor and Log Analytics.
- Assign the Azure AI Enterprise Network Connection Approver role to the hub's managed identity for private endpoint approval.
- Regularly review outbound rules and remove unnecessary access.
- Be aware of cost implications for Azure Firewall and Private Link.

---

## Detailed Example: End-to-End Connectivity Flow for a Customer Web App

This section provides in-depth connectivity flows for a customer web application consuming AI Foundry resources, covering both Azure-hosted and on-premises deployments, and both network isolation models. It highlights the use of private endpoints, managed VNets, and hybrid networking.

### Scenario 1: Web App Deployed in Azure
#### a) Allow Internet Outbound
1. **Web App Location**: The web app is deployed in Azure (App Service, AKS, VM, etc.), in its own VNet or subnet.
2. **Connectivity to AI Foundry**:
    - The web app can connect to AI Foundry endpoints over the public internet if public endpoints are enabled.
    - For secure access, the web app's VNet can be integrated with the AI Foundry managed VNet using VNet peering or Private Link Service.
    - If VNet peering is used, the web app can resolve and connect to AI Foundry resources via their private endpoints, traversing the Azure backbone only.
3. **Private Endpoints**:
    - AI Foundry exposes private endpoints for its services (model endpoints, vector DB, etc.) within the managed VNet.
    - The web app's VNet must be able to resolve the private DNS zones associated with these endpoints (either via DNS forwarding or linking the private DNS zone to both VNets).
4. **Data Flow**:
    - Web App (Azure VNet) → [VNet Peering/Private Link] → AI Foundry Managed VNet (Private Endpoints) → AI Foundry Resources
    - If public endpoints are used, traffic may traverse the public internet, which is not recommended for sensitive data.

#### b) Allow Only Approved Outbound
1. **Web App Location**: Same as above, but public endpoints are disabled for AI Foundry.
2. **Connectivity to AI Foundry**:
    - The web app must connect to AI Foundry resources via private endpoints only.
    - VNet peering or Private Link Service is required between the web app's VNet and the AI Foundry managed VNet.
    - The web app's VNet must have access to the private DNS zones for AI Foundry endpoints.
3. **Outbound Restrictions**:
    - All outbound traffic from the AI Foundry managed VNet is denied except for explicitly allowed destinations (private endpoints, service tags, FQDNs via Azure Firewall).
    - The web app can only access AI Foundry resources through the Azure backbone, never via the public internet.
4. **Data Flow**:
    - Web App (Azure VNet) → [VNet Peering/Private Link] → AI Foundry Managed VNet (Private Endpoints) → AI Foundry Resources

**Diagram:**
```
Web App (Azure VNet)
   │
   ├─[VNet Peering/Private Link]
   │
AI Foundry Managed VNet (Private Endpoints)
   │
AI Foundry Resources (Models, Vector DB, etc.)
```

---

### Scenario 2: Web App Deployed On-Premises
#### a) Allow Internet Outbound
1. **Web App Location**: The web app runs in the customer’s on-premises datacenter.
2. **Connectivity to AI Foundry**:
    - The on-premises network is connected to Azure via VPN Gateway or ExpressRoute.
    - The web app can connect to AI Foundry public endpoints over the internet (if enabled), or to private endpoints via the hybrid connection.
    - For secure access, the on-premises DNS must be able to resolve the private DNS zones for AI Foundry endpoints (typically via DNS forwarding from Azure to on-premises).
3. **Private Endpoints**:
    - AI Foundry exposes private endpoints in the managed VNet.
    - The on-premises network must be able to route to the managed VNet (via VPN/ExpressRoute) and resolve private DNS names.
4. **Data Flow**:
    - Web App (On-Premises) → [VPN/ExpressRoute] → Azure VNet (AI Foundry Managed VNet) → Private Endpoints → AI Foundry Resources
    - If public endpoints are used, traffic may traverse the public internet.

#### b) Allow Only Approved Outbound
1. **Web App Location**: Same as above, but public endpoints are disabled for AI Foundry.
2. **Connectivity to AI Foundry**:
    - The on-premises web app must connect to AI Foundry resources via private endpoints only.
    - The on-premises network must be connected to the AI Foundry managed VNet via VPN Gateway or ExpressRoute.
    - Private DNS resolution must be configured so that on-premises clients can resolve the private endpoint names (using DNS forwarding or conditional forwarding to Azure DNS).
3. **Outbound Restrictions**:
    - All outbound traffic from the AI Foundry managed VNet is denied except for explicitly allowed destinations.
    - The on-premises web app can only access AI Foundry resources through the private Azure backbone, never via the public internet.
4. **Data Flow**:
    - Web App (On-Premises) → [VPN/ExpressRoute] → Azure VNet (AI Foundry Managed VNet) → Private Endpoints → AI Foundry Resources

**Diagram:**
```
Web App (On-Premises)
   │
   ├─[VPN Gateway/ExpressRoute]
   │
AI Foundry Managed VNet (Private Endpoints)
   │
AI Foundry Resources (Models, Vector DB, etc.)
```

---

**Key Considerations:**
- For both Azure and on-premises web apps, using private endpoints and integrated VNets ensures all data remains on the Azure backbone, maximizing security and compliance.
- Private DNS zones must be properly linked or forwarded to all participating networks (Azure and on-premises) for seamless name resolution.
- VNet peering, Private Link, and hybrid connectivity (VPN/ExpressRoute) are essential for secure, private access to AI Foundry resources.
- In "Allow Only Approved Outbound" mode, public endpoints are not available, and all access must be via private networking.

---

## References
- [Configure managed network for Azure AI Foundry](https://learn.microsoft.com/en-gb/azure/ai-foundry/how-to/configure-managed-network?tabs=portal)
- [Azure Private Endpoint Overview](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Firewall Pricing](https://azure.microsoft.com/pricing/details/azure-firewall/)
- [Access on-premises resources from Azure AI Foundry](https://learn.microsoft.com/en-gb/azure/ai-foundry/how-to/access-on-premises-resources)

---

For a detailed visual representation, see `ai-foundry-infra-networking.drawio` in this repository.
