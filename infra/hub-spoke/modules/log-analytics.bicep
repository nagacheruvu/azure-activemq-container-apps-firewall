// ============================================================================
// Log Analytics Workspace — centralized logging for Hub Firewall & Spokes
// ============================================================================

@description('Location')
param location string

@description('Workspace name')
param workspaceName string

@description('Retention in days')
param retentionDays int = 30

param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name

@description('Log Analytics primary shared key')
#disable-next-line outputs-should-not-contain-secrets
output sharedKey string = workspace.listKeys().primarySharedKey
