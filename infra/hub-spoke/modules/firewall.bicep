// ============================================================================
// Azure Firewall (Basic SKU) — deployed in Hub VNet
// ============================================================================
// Centralized firewall for all spoke VNets:
//   - DNAT rules route inbound TCP to spoke workloads via peering
//   - Network rules control outbound from spoke subnets
//   - Diagnostics sent to Log Analytics
// ============================================================================

@description('Location')
param location string

@description('Firewall name')
param firewallName string

@description('Firewall PIP name')
param firewallPipName string

@description('Firewall Policy name')
param firewallPolicyName string

@description('Hub AzureFirewallSubnet resource ID')
param firewallSubnetId string

@description('Hub AzureFirewallManagementSubnet resource ID (required for Basic SKU)')
param firewallMgmtSubnetId string

@description('Source IPs allowed via DNAT rules')
param whitelistedIPs array

@description('ActiveMQ internal FQDN or IP in spoke VNet (set after ACA env deploys)')
param activeMqInternalIP string

@description('Spoke VNet address prefix for network rules')
param spokeAddressPrefix string = '10.1.0.0/16'

param tags object = {}

// ============================================================================
// Public IPs
// ============================================================================
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: firewallPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallMgmtPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${firewallPipName}-mgmt'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// Firewall Policy (Basic tier)
// ============================================================================
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
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

// ============================================================================
// DNAT Rule Collection — Inbound to ActiveMQ (via peering to spoke)
// ============================================================================
resource dnatRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: firewallPolicy
  name: 'DefaultDnatRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        name: 'activemq-inbound'
        priority: 100
        action: {
          type: 'Dnat'
        }
        rules: [
          {
            ruleType: 'NatRule'
            name: 'allow-activemq-openwire'
            description: 'DNAT whitelisted IPs to ActiveMQ OpenWire (port 61616) in spoke'
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
            name: 'allow-activemq-webconsole'
            description: 'DNAT whitelisted IPs to ActiveMQ Web Console (port 8161) in spoke'
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
            name: 'allow-activemq-stomp'
            description: 'DNAT whitelisted IPs to ActiveMQ STOMP (port 61613) in spoke'
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
    ]
  }
}

// ============================================================================
// Network Rule Collection — Outbound from Spoke + Deny All
// ============================================================================
resource networkRuleCollection 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'spoke-outbound-allow'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allow-dns'
            description: 'Allow DNS resolution from spoke workloads'
            sourceAddresses: [
              spokeAddressPrefix
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '53'
            ]
            ipProtocols: [
              'TCP'
              'UDP'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'allow-https-outbound'
            description: 'Allow HTTPS outbound from spoke for container pulls, updates'
            sourceAddresses: [
              spokeAddressPrefix
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
            name: 'allow-ntp'
            description: 'Allow NTP for time sync'
            sourceAddresses: [
              spokeAddressPrefix
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '123'
            ]
            ipProtocols: [
              'UDP'
            ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'deny-all'
        priority: 65000
        action: {
          type: 'Deny'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'deny-all-outbound'
            description: 'Explicit deny-all for spoke egress (catch-all)'
            sourceAddresses: [
              spokeAddressPrefix
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
  dependsOn: [
    dnatRuleCollection
  ]
}

// ============================================================================
// Azure Firewall (Basic SKU)
// ============================================================================
resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
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
    networkRuleCollection
  ]
}

// ============================================================================
// Outputs
// ============================================================================
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = firewallPip.properties.ipAddress
output firewallName string = firewall.name
