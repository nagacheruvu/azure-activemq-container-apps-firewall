// ============================================================================
// Spoke Route Table Update — UDR 0.0.0.0/0 → Hub Firewall Private IP
// ============================================================================
// This forces all egress from spoke ACA subnet through the Hub Firewall.
// Deployed after Firewall so we know its private IP.
// ============================================================================

@description('Spoke route table name')
param routeTableName string

@description('Hub Azure Firewall private IP')
param hubFirewallPrivateIp string

resource routeTable 'Microsoft.Network/routeTables@2023-09-01' existing = {
  name: routeTableName
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2023-09-01' = {
  parent: routeTable
  name: 'force-egress-to-hub-firewall'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: hubFirewallPrivateIp
  }
}
