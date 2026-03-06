// ============================================================================
// Container Apps Environment — VNet-injected, internal-only (in Spoke VNet)
// ============================================================================

@description('Location')
param location string

@description('Environment name')
param envName string

@description('Spoke aca-subnet resource ID')
param infrastructureSubnetId string

@description('Log Analytics workspace ID')
param logAnalyticsWorkspaceId string

@description('Log Analytics shared key')
@secure()
param logAnalyticsSharedKey string

param tags object = {}

resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: true  // No public endpoint — all ingress via Hub Firewall DNAT
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        sharedKey: logAnalyticsSharedKey
      }
    }
  }
}

output envId string = acaEnv.id
output envName string = acaEnv.name
output defaultDomain string = acaEnv.properties.defaultDomain
output staticIp string = acaEnv.properties.staticIp
