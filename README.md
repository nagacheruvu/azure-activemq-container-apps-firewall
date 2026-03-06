# ActiveMQ on Azure Container Apps with Azure Firewall - MVP

## Architecture

```
                       INTERNET
                          │
                ┌─────────▼──────────┐
                │   Azure Firewall    │
                │  Public IP (SNAT)   │
                │                     │
                │  DNAT Rules:        │
                │  ✅ Whitelisted IP  │──→ ALLOW ──→ ActiveMQ :61616
                │  ❌ Other IPs       │──→ DROP
                └─────────┬──────────┘
                          │ Private IP: 10.0.1.4
                ┌─────────▼──────────┐
                │       VNet          │
                │    10.0.0.0/16      │
                │                     │
                │  ┌───────────────┐  │
                │  │  ACA Subnet   │  │
                │  │ 10.0.16.0/20  │  │
                │  │               │  │
                │  │  ┌─────────┐  │  │
                │  │  │ActiveMQ │  │  │
                │  │  │TCP:61616│  │  │
                │  │  │HTTP:8161│  │  │
                │  │  └─────────┘  │  │
                │  └───────────────┘  │
                └─────────────────────┘
                          │
                UDR: 0.0.0.0/0 → Firewall
                (All egress forced through FW)
```

## Azure Firewall Egress IP (SNAT) Behavior

| Scenario | Egress IP Behavior |
|----------|-------------------|
| 1 Public IP | All outbound traffic always uses that single IP |
| Multiple Public IPs | Azure Firewall can SNAT using **any** of them |

**Key**: Azure Firewall performs Source NAT (SNAT) on all outbound internet traffic. The Firewall's Public IP becomes the egress identity of your workload.

## Project Structure

```
az-active-mq-aca-firewall-mvp/
├── infra/
│   ├── main.bicep                    # Single-VNet deployment (demo/dev)
│   ├── parameters.json               # Deployment parameters
│   ├── modules/                      # Modules for single-VNet topology
│   │   ├── networking.bicep           # VNet, Subnets, Route Table
│   │   ├── firewall.bicep             # Azure Firewall + DNAT/Network rules
│   │   ├── log-analytics.bicep        # Log Analytics Workspace
│   │   ├── aca-environment.bicep      # Container Apps Environment
│   │   ├── activemq-app.bicep         # ActiveMQ Container App
│   │   └── route-table-update.bicep   # UDR to force egress through Firewall
│   └── hub-spoke/                    # ⭐ Hub-Spoke topology (production-recommended)
│       ├── main.bicep                 # Hub-Spoke orchestrator
│       ├── parameters.json            # Hub-Spoke parameters
│       └── modules/
│           ├── hub-networking.bicep    # Hub VNet (Firewall subnets)
│           ├── spoke-networking.bicep  # Spoke VNet (ACA subnet + UDR)
│           ├── vnet-peering.bicep      # Bidirectional Hub ↔ Spoke peering
│           ├── firewall.bicep          # Centralized Firewall in Hub
│           ├── log-analytics.bicep     # Shared Log Analytics
│           ├── aca-environment.bicep   # ACA Environment in Spoke
│           ├── activemq-app.bicep      # ActiveMQ Container App
│           └── spoke-route-update.bicep # UDR 0.0.0.0/0 → Hub Firewall
├── notebooks/
│   ├── 01-deploy-infrastructure.ipynb # Cost estimation + IaC deployment
│   ├── 02-activemq-client-demo.ipynb  # Client tests (whitelisted vs blocked)
│   └── 03-hub-spoke-architecture.ipynb # Hub-Spoke recommendation for customer
└── README.md
```

## Quick Start

### 1. Review Costs (Notebook 01 - Cell 2)

Run the cost estimator before deploying:

| Service | Estimated Monthly Cost |
|---------|----------------------|
| Azure Firewall **Basic** | ~$288.35 |
| Firewall Data Processing (100 GB) | ~$1.60 |
| Public IP (Static x2) | ~$7.30 |
| Container Apps (1 vCPU, 2 GiB) | ~$21.90 |
| Log Analytics (5 GB) | ~$13.80 |
| VNet | Free |
| **Total** | **~$333/month** |

> **Using Basic SKU** for dev/demo. For production, upgrade to Standard (~$912/month) for TLS inspection, IDPS, 30 Gbps throughput.

### 2. Deploy Infrastructure (Notebook 01)

Open `notebooks/01-deploy-infrastructure.ipynb` and run cells sequentially:
1. Cost estimation (review before deploying)
2. Configure parameters (subscription, IPs)
3. Azure login
4. Create resource group
5. Deploy Bicep template (~15-20 min)
6. Verify resources

### 3. Test Client Access (Notebook 02)

Open `notebooks/02-activemq-client-demo.ipynb`:
1. **Test 1**: TCP connection from whitelisted IP → ✅ Should succeed
2. **Test 1b**: STOMP message send/receive → ✅ Should work
3. **Test 2**: Connection to non-DNAT port → ❌ Should timeout
4. **Test 2b**: Firewall deny logs → Shows blocked attempts
5. **Test 3**: Side-by-side comparison table

## Security Controls

| Layer | Control | Purpose |
|-------|---------|---------|
| Perimeter | Azure Firewall DNAT | Only whitelisted IPs reach ActiveMQ |
| Network | VNet + Internal ACA | ActiveMQ not directly exposed to internet |
| Egress | UDR + Firewall SNAT | All outbound exits via known Firewall IP |
| Monitoring | Firewall Logs | Full audit trail (allowed + denied) |
| Default Deny | Implicit deny | Everything not explicitly allowed is blocked |

## Hub-Spoke Architecture (Production Recommendation)

For production, we recommend the **Hub-Spoke** topology with a centralized Azure Firewall in the Hub VNet:

```
                      INTERNET
                         │
              ┌──────────▼──────────┐
              │    Hub VNet          │
              │    10.0.0.0/16       │
              │                      │
              │  ┌────────────────┐  │
              │  │ Azure Firewall │  │
              │  │  (Centralized) │  │
              │  └───────┬────────┘  │
              └──────────┼──────────┘
                    VNet Peering
           ┌─────────────┼─────────────┐
           │             │             │
   ┌───────▼──────┐ ┌───▼──────┐ ┌───▼──────┐
   │  Spoke 1     │ │ Spoke 2  │ │ Spoke N  │
   │  ActiveMQ    │ │ Other    │ │ Future   │
   │  10.1.0.0/16 │ │ Workload │ │ Workload │
   └──────────────┘ └──────────┘ └──────────┘
```

**Why Hub-Spoke?**
- **One Firewall, many workloads** — share the ~$288/mo cost across spokes
- **Network isolation** — each spoke is isolated; cross-spoke traffic goes through Firewall
- **Scalable** — add new spoke VNets without touching the Firewall instance
- **Consistent policy** — uniform security rules enforced centrally

**Deploy Hub-Spoke:**
```bash
az deployment group create \
  --resource-group rg-activemq-firewall-mvp \
  --template-file infra/hub-spoke/main.bicep \
  --parameters infra/hub-spoke/parameters.json
```

See `notebooks/03-hub-spoke-architecture.ipynb` for detailed architecture comparison and customer-ready diagrams.

## Cleanup

To stop all costs, delete the resource group:
```bash
az group delete --name rg-activemq-firewall-mvp --yes --no-wait
```
