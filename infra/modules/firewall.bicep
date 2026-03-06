// ============================================================================
// Azure Firewall Module (Basic SKU - Dev/Demo)
// ============================================================================
// Azure Firewall Basic is cost-effective for dev/test (~$0.395/hr vs $1.25/hr)
// It supports:
//   - SNAT: All outbound traffic exits via Firewall's Public IP
//   - DNAT: Inbound TCP traffic (61616, 8161, 61613) forwarded to ActiveMQ
//   - Network Rules: Only whitelisted source IPs can connect
//   - Threat Intel in alert-only mode
//
// Basic vs Standard:
//   Basic:    ~$288/mo, 250 Mbps throughput, suitable for SMB/dev
//   Standard: ~$912/mo, 30 Gbps throughput, TLS inspection, IDPS
//
// Key Concept - SNAT Behavior:
//   1 Public IP  → Always that IP for egress
//   Multiple IPs → Azure picks any for SNAT (round-robin-like)
// ============================================================================

param location string
param firewallName string
param firewallPipName string
param firewallPolicyName string
param firewallSubnetId string
param firewallMgmtSubnetId string
param whitelistedIPs array
param activeMqInternalIP string
param logAnalyticsWorkspaceId string
param tags object

// Public IP for Azure Firewall (this becomes the egress/SNAT IP)
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: firewallPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Management Public IP (required for Basic SKU)
resource firewallMgmtPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${firewallPipName}-mgmt'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Firewall Policy - contains all rules
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }
}

// Rule Collection Group - Network + DNAT rules
resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  parent: firewallPolicy
  name: 'ActiveMQ-Rules'
  properties: {
    priority: 100
    ruleCollections: [
      {
        // DNAT Rule: Forward inbound TCP to ActiveMQ inside the VNet
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'ActiveMQ-DNAT-Rules'
        priority: 100
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'Allow-ActiveMQ-OpenWire-Whitelisted'
            description: 'Forward TCP 61616 (OpenWire) from whitelisted IPs to ActiveMQ'
            sourceAddresses: whitelistedIPs
            destinationAddresses: [
              firewallPip.properties.ipAddress
            ]
            destinationPorts: [
              '61616'
            ]
            ipProtocols: [
              'TCP'
            ]
            translatedAddress: activeMqInternalIP
            translatedPort: '61616'
          }
          {
            ruleType: 'NatRule'
            name: 'Allow-ActiveMQ-WebConsole-Whitelisted'
            description: 'Forward TCP 8161 (Web Console) from whitelisted IPs to ActiveMQ'
            sourceAddresses: whitelistedIPs
            destinationAddresses: [
              firewallPip.properties.ipAddress
            ]
            destinationPorts: [
              '8161'
            ]
            ipProtocols: [
              'TCP'
            ]
            translatedAddress: activeMqInternalIP
            translatedPort: '8161'
          }
          {
            ruleType: 'NatRule'
            name: 'Allow-ActiveMQ-STOMP-Whitelisted'
            description: 'Forward TCP 61613 (STOMP) from whitelisted IPs to ActiveMQ'
            sourceAddresses: whitelistedIPs
            destinationAddresses: [
              firewallPip.properties.ipAddress
            ]
            destinationPorts: [
              '61613'
            ]
            ipProtocols: [
              'TCP'
            ]
            translatedAddress: activeMqInternalIP
            translatedPort: '61613'
          }
        ]
      }
      {
        // Network Rule: Control outbound traffic from ACA
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ActiveMQ-Network-Rules'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow-ACA-DNS'
            description: 'Allow DNS resolution from Container Apps'
            sourceAddresses: [
              '10.0.16.0/20'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '53'
            ]
            ipProtocols: [
              'UDP'
              'TCP'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-ACA-HTTPS-Outbound'
            description: 'Allow HTTPS outbound for container image pulls'
            sourceAddresses: [
              '10.0.16.0/20'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '443'
            ]
            ipProtocols: [
              'TCP'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Allow-DNAT-ActiveMQ-Translated'
            description: 'Explicit allow for DNAT translated traffic to ACA (ActiveMQ ports)'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              activeMqInternalIP
            ]
            destinationPorts: [
              '61616'
              '8161'
              '61613'
            ]
            ipProtocols: [
              'TCP'
            ]
          }
        ]
      }
      {
        // Deny-all implicit (Azure Firewall denies by default)
        // Any traffic not matching above rules is DROPPED
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Deny-All-Other'
        priority: 65000
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Deny-All'
            description: 'Deny all other traffic (explicit deny for logging)'
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            ipProtocols: [
              'Any'
            ]
          }
        ]
      }
    ]
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'fw-ipconfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
    // Management IP configuration - required for Basic SKU
    managementIpConfiguration: {
      name: 'fw-mgmt-ipconfig'
      properties: {
        subnet: {
          id: firewallMgmtSubnetId
        }
        publicIPAddress: {
          id: firewallMgmtPip.id
        }
      }
    }
  }
  dependsOn: [
    ruleCollectionGroup
  ]
}

// Diagnostic Settings - log all firewall traffic
resource firewallDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${firewallName}-diag'
  scope: firewall
  properties: {
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspaceId
  }
}

output firewallPublicIp string = firewallPip.properties.ipAddress
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallName string = firewall.name
output firewallPolicyName string = firewallPolicy.name
output firewallResourceId string = firewall.id
