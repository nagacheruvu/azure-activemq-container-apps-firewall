// ============================================================================
// Networking Module - VNet, Subnets, Route Table
// ============================================================================
// VNet Address Space: 10.0.0.0/16
//   - AzureFirewallSubnet:           10.0.1.0/24  (required for Azure Firewall)
//   - AzureFirewallManagementSubnet: 10.0.2.0/24  (required for Basic SKU)
//   - aca-subnet:                    10.0.16.0/20 (Container Apps needs /23 min)
// ============================================================================

param location string
param vnetName string
param routeTableName string
param tags object

// Route Table for UDR (User Defined Routes) to force egress through firewall
resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []  // Routes added after firewall is deployed
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
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
        // Azure Firewall REQUIRES a subnet named exactly 'AzureFirewallSubnet'
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        // Basic SKU REQUIRES 'AzureFirewallManagementSubnet' for management traffic
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'aca-subnet'
        properties: {
          addressPrefix: '10.0.16.0/20'
          routeTable: {
            id: routeTable.id
          }
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output firewallSubnetId string = vnet.properties.subnets[0].id
output firewallMgmtSubnetId string = vnet.properties.subnets[1].id
output acaSubnetId string = vnet.properties.subnets[2].id
output routeTableName string = routeTable.name
output routeTableId string = routeTable.id
