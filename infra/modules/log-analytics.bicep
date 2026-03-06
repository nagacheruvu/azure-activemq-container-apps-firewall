// ============================================================================
// Log Analytics Workspace Module
// ============================================================================

param location string
param workspaceName string
param retentionDays int = 30
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
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

output workspaceId string = logAnalyticsWorkspace.id
output workspaceName string = logAnalyticsWorkspace.name
output sharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey
