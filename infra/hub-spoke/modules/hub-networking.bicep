// ============================================================================
// Hub VNet — hosts Azure Firewall (centralized network security)
// ============================================================================
// Address Space: 10.0.0.0/16
// Subnets:
//   AzureFirewallSubnet      - 10.0.1.0/24 (mandatory name for Firewall)
//   AzureFirewallManagementSubnet - 10.0.2.0/24 (required for Basic SKU)
// ============================================================================

@description('Location for hub VNet')
param location string

@description('Hub VNet name')
param hubVnetName string

param tags object = {}

// ============================================================================
// Hub Virtual Network
// ============================================================================
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================
output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output firewallSubnetId string = hubVnet.properties.subnets[0].id
output firewallMgmtSubnetId string = hubVnet.properties.subnets[1].id
