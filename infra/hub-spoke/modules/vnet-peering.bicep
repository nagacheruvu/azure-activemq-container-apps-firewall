// ============================================================================
// VNet Peering — Hub ↔ Spoke bidirectional peering
// ============================================================================
// Settings:
//   allowForwardedTraffic: true   → Spoke traffic forwarded through Hub FW
//   allowGatewayTransit: true     → Hub can share VPN/ER gateway with spokes
//   useRemoteGateways: false      → No gateway in this demo (set true if Hub has VPN GW)
//   allowVirtualNetworkAccess: true → Required for cross-VNet communication
// ============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Spoke VNet name')
param spokeVnetName string

@description('Hub VNet resource ID')
param hubVnetId string

@description('Spoke VNet resource ID')
param spokeVnetId string

// ============================================================================
// Hub → Spoke peering
// ============================================================================
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  name: '${hubVnetName}/hub-to-${spokeVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true     // Hub can transit for spokes
    useRemoteGateways: false
  }
}

// ============================================================================
// Spoke → Hub peering
// ============================================================================
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  name: '${spokeVnetName}/spoke-to-${hubVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false      // Set true if Hub has VPN/ER Gateway
  }
}

// ============================================================================
// Outputs
// ============================================================================
output hubToSpokePeeringState string = hubToSpokePeering.properties.peeringState
output spokeToHubPeeringState string = spokeToHubPeering.properties.peeringState
