// ============================================================================
// Spoke VNet — hosts workloads (Container Apps with ActiveMQ)
// ============================================================================
// Address Space: 10.1.0.0/16
// Subnets:
//   aca-subnet - 10.1.0.0/20 (delegated to Container Apps, /23 minimum)
// Route Table:
//   Attached to aca-subnet, UDR added later via spoke-route-update module
// ============================================================================

@description('Location for spoke VNet')
param location string

@description('Spoke VNet name')
param spokeVnetName string

@description('Route table name')
param routeTableName string

param tags object = {}

// ============================================================================
// Route Table (attached to spoke subnet, routes populated after FW deploys)
// ============================================================================
resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
  }
}

// ============================================================================
// Spoke Virtual Network
// ============================================================================
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aca-subnet'
        properties: {
          addressPrefix: '10.1.0.0/20'
          routeTable: {
            id: routeTable.id
          }
          delegations: [
            {
              name: 'aca-delegation'
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

// ============================================================================
// Outputs
// ============================================================================
output spokeVnetId string = spokeVnet.id
output spokeVnetName string = spokeVnet.name
output acaSubnetId string = spokeVnet.properties.subnets[0].id
output routeTableName string = routeTable.name
