// ============================================================================
// Route Table Update Module
// ============================================================================
// Adds UDR (User Defined Route) to force all egress traffic
// from Container Apps subnet through Azure Firewall
// ============================================================================

param routeTableName string
param firewallPrivateIp string

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' existing = {
  name: routeTableName
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2023-11-01' = {
  parent: routeTable
  name: 'force-firewall-egress'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallPrivateIp
  }
}
