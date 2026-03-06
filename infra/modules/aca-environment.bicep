// ============================================================================
// Container Apps Environment Module
// ============================================================================
// Deploys into the VNet subnet with internal-only access
// All egress traffic is routed through Azure Firewall via UDR
// ============================================================================

param location string
param envName string
param infrastructureSubnetId string
param logAnalyticsWorkspaceId string

@secure()
param logAnalyticsSharedKey string
param tags object

resource acaEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: true  // Internal only - not directly exposed to internet
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    zoneRedundant: false  // Set to true for production
  }
}

output envId string = acaEnv.id
output envName string = acaEnv.name
output defaultDomain string = acaEnv.properties.defaultDomain
output staticIp string = acaEnv.properties.staticIp
