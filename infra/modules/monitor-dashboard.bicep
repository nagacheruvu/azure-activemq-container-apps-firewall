// ============================================================================
// Azure Monitor Dashboard Module - Firewall Traffic Insights
// ============================================================================
// Deploys an Azure Portal Dashboard with tiles for:
//   1. Denied traffic (last 24h) - quickly spot blocked connections
//   2. Allowed traffic (last 24h) - verify legitimate access
//   3. Top denied source IPs - identify attackers/misconfigurations
//   4. Traffic by port - see which services are being accessed
//   5. Firewall health metrics - throughput, latency, health state
//   6. DNAT rule hit counts - validate DNAT forwarding
//
// Also deploys a Log Analytics Workbook for deeper drill-down analysis.
// ============================================================================

param location string
param dashboardName string
param workbookName string
param logAnalyticsWorkspaceId string
param firewallResourceId string
param tags object

// ============================================================================
// Azure Portal Dashboard
// ============================================================================
resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: dashboardName
  location: location
  tags: union(tags, {
    'hidden-title': 'ActiveMQ Firewall Traffic Dashboard'
  })
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          // ── Title ──
          {
            position: { x: 0, y: 0, colSpan: 12, rowSpan: 1 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              inputs: []
              settings: {
                content: {
                  settings: {
                    content: '# 🔥 ActiveMQ Firewall Traffic Dashboard\n**Azure Firewall** → Denied & Allowed traffic to ActiveMQ on Azure Container Apps'
                    title: ''
                    subtitle: ''
                    markdownSource: 1
                    markdownUri: null
                  }
                }
              }
            }
          }
          // ── Firewall Health ──
          {
            position: { x: 0, y: 1, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: { id: firewallResourceId }
                          name: 'FirewallHealth'
                          aggregationType: 4 // Average
                          namespace: 'Microsoft.Network/azureFirewalls'
                          metricVisualization: {
                            displayName: 'Firewall Health'
                            resourceDisplayName: 'Firewall'
                          }
                        }
                      ]
                      title: '🏥 Firewall Health State'
                      titleKind: 2
                      visualization: { chartType: 2 } // Line
                      timespan: { relative: { duration: 86400000 } } // 24h
                    }
                  }
                }
              ]
            }
          }
          // ── Throughput ──
          {
            position: { x: 4, y: 1, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: { id: firewallResourceId }
                          name: 'Throughput'
                          aggregationType: 4
                          namespace: 'Microsoft.Network/azureFirewalls'
                          metricVisualization: {
                            displayName: 'Throughput (bps)'
                            resourceDisplayName: 'Firewall'
                          }
                        }
                      ]
                      title: '📊 Firewall Throughput'
                      titleKind: 2
                      visualization: { chartType: 2 }
                      timespan: { relative: { duration: 86400000 } }
                    }
                  }
                }
              ]
            }
          }
          // ── Data Processed ──
          {
            position: { x: 8, y: 1, colSpan: 4, rowSpan: 3 }
            metadata: {
              type: 'Extension/HubsExtension/PartType/MonitorChartPart'
              inputs: [
                {
                  name: 'options'
                  value: {
                    chart: {
                      metrics: [
                        {
                          resourceMetadata: { id: firewallResourceId }
                          name: 'DataProcessed'
                          aggregationType: 1 // Total
                          namespace: 'Microsoft.Network/azureFirewalls'
                          metricVisualization: {
                            displayName: 'Data Processed'
                            resourceDisplayName: 'Firewall'
                          }
                        }
                      ]
                      title: '💾 Data Processed'
                      titleKind: 2
                      visualization: { chartType: 2 }
                      timespan: { relative: { duration: 86400000 } }
                    }
                  }
                }
              ]
            }
          }
          // ── Log Analytics: Denied Traffic ──
          {
            position: { x: 0, y: 4, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'resourceTypeMode'
                  value: 'workspace'
                }
                {
                  name: 'ComponentId'
                  value: logAnalyticsWorkspaceId
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                }
                {
                  name: 'Query'
                  value: 'AzureDiagnostics\n| where Category == "AzureFirewallNetworkRule"\n| where msg_s has "Deny"\n| extend SourceIP = extract(@"from (\\d+\\.\\d+\\.\\d+\\.\\d+)", 1, msg_s)\n| extend DestPort = extract(@":(\\d+)\\.", 1, msg_s)\n| summarize DenyCount=count() by SourceIP, DestPort\n| order by DenyCount desc\n| take 20'
                }
                {
                  name: 'PartTitle'
                  value: '❌ Top Denied Connections (24h)'
                }
              ]
            }
          }
          // ── Log Analytics: Allowed DNAT Traffic ──
          {
            position: { x: 6, y: 4, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'resourceTypeMode'
                  value: 'workspace'
                }
                {
                  name: 'ComponentId'
                  value: logAnalyticsWorkspaceId
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                }
                {
                  name: 'Query'
                  value: 'AzureDiagnostics\n| where Category == "AzureFirewallNatRule"\n| extend SourceIP = extract(@"from (\\d+\\.\\d+\\.\\d+\\.\\d+)", 1, msg_s)\n| extend DestPort = extract(@":(\\d+)$", 1, msg_s)\n| summarize AllowCount=count() by SourceIP, DestPort\n| order by AllowCount desc\n| take 20'
                }
                {
                  name: 'PartTitle'
                  value: '✅ DNAT Allowed Connections (24h)'
                }
              ]
            }
          }
          // ── Log Analytics: Denied Over Time ──
          {
            position: { x: 0, y: 8, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'resourceTypeMode'
                  value: 'workspace'
                }
                {
                  name: 'ComponentId'
                  value: logAnalyticsWorkspaceId
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                }
                {
                  name: 'Query'
                  value: 'AzureDiagnostics\n| where Category == "AzureFirewallNetworkRule"\n| where msg_s has "Deny"\n| summarize DenyCount=count() by bin(TimeGenerated, 15m)\n| render timechart with (title="Denied Connections Over Time")'
                }
                {
                  name: 'PartTitle'
                  value: '📈 Denied Traffic Timeline (15m bins)'
                }
                {
                  name: 'Dimensions'
                  value: { xAxis: { name: 'TimeGenerated', type: 'datetime' }, yAxis: [ { name: 'DenyCount', type: 'long' } ] }
                }
                {
                  name: 'VisualizationType'
                  value: 'linechart'
                }
              ]
            }
          }
          // ── Log Analytics: Traffic by Port ──
          {
            position: { x: 6, y: 8, colSpan: 6, rowSpan: 4 }
            metadata: {
              type: 'Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart'
              inputs: [
                {
                  name: 'resourceTypeMode'
                  value: 'workspace'
                }
                {
                  name: 'ComponentId'
                  value: logAnalyticsWorkspaceId
                }
                {
                  name: 'TimeRange'
                  value: 'P1D'
                }
                {
                  name: 'Query'
                  value: 'AzureDiagnostics\n| where Category in ("AzureFirewallNetworkRule", "AzureFirewallNatRule")\n| extend Action = iif(msg_s has "Deny", "Deny", "Allow")\n| extend DestPort = extract(@":(\\d+)[\\s\\.]", 1, msg_s)\n| where isnotempty(DestPort)\n| summarize Count=count() by DestPort, Action\n| order by Count desc\n| take 20'
                }
                {
                  name: 'PartTitle'
                  value: '🔢 Traffic by Destination Port (24h)'
                }
              ]
            }
          }
        ]
      }
    ]
  }
}

// ============================================================================
// Log Analytics Workbook for deep drill-down
// ============================================================================
var workbookContent = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# 🔥 ActiveMQ Firewall Traffic Workbook\nInteractive workbook for troubleshooting denied traffic and monitoring ActiveMQ access patterns through Azure Firewall.'
      }
      name: 'title'
    }
    {
      type: 9
      content: {
        version: 'KqlParameterItem/1.0'
        parameters: [
          {
            id: 'timeRange'
            version: 'KqlParameterItem/1.0'
            name: 'TimeRange'
            type: 4
            isRequired: true
            value: { durationMs: 86400000 }
            typeSettings: {
              selectableValues: [
                { durationMs: 3600000 }
                { durationMs: 14400000 }
                { durationMs: 86400000 }
                { durationMs: 259200000 }
                { durationMs: 604800000 }
              ]
            }
            label: 'Time Range'
          }
        ]
      }
      name: 'parameters'
    }
    {
      type: 1
      content: {
        json: '## ❌ Denied Connections\nConnections blocked by Azure Firewall network rules. Use this to identify misconfigurations, missing whitelist entries, or attack attempts.'
      }
      name: 'denied-header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AzureDiagnostics\n| where Category == "AzureFirewallNetworkRule"\n| where msg_s has "Deny"\n| summarize DenyCount=count() by bin(TimeGenerated, 15m)\n| render timechart'
        size: 0
        title: 'Denied Connections Over Time'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
      }
      name: 'denied-timeline'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AzureDiagnostics\n| where Category == "AzureFirewallNetworkRule"\n| where msg_s has "Deny"\n| extend SourceIP = extract(@"from (\\d+\\.\\d+\\.\\d+\\.\\d+)", 1, msg_s)\n| extend DestPort = extract(@":(\\d+)\\.", 1, msg_s)\n| summarize DenyCount=count(), LastSeen=max(TimeGenerated) by SourceIP, DestPort\n| order by DenyCount desc\n| take 50'
        size: 0
        title: 'Top Denied Source IPs & Ports'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        gridSettings: {
          formatters: [
            { columnMatch: 'DenyCount', formatter: 4, formatOptions: { palette: 'redGreen' } }
          ]
        }
      }
      name: 'denied-sources'
    }
    {
      type: 1
      content: {
        json: '## ✅ Allowed DNAT Connections\nSuccessful connections forwarded by DNAT rules to ActiveMQ.'
      }
      name: 'allowed-header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AzureDiagnostics\n| where Category == "AzureFirewallNatRule"\n| summarize AllowCount=count() by bin(TimeGenerated, 15m)\n| render timechart'
        size: 0
        title: 'DNAT Forwarded Connections Over Time'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'timechart'
      }
      name: 'dnat-timeline'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AzureDiagnostics\n| where Category == "AzureFirewallNatRule"\n| extend SourceIP = extract(@"from (\\d+\\.\\d+\\.\\d+\\.\\d+)", 1, msg_s)\n| extend OrigDest = extract(@"to (\\d+\\.\\d+\\.\\d+\\.\\d+:\\d+)", 1, msg_s)\n| extend TranslatedDest = extract(@"translated to (\\d+\\.\\d+\\.\\d+\\.\\d+:\\d+)", 1, msg_s)\n| summarize HitCount=count(), LastSeen=max(TimeGenerated) by SourceIP, OrigDest, TranslatedDest\n| order by HitCount desc\n| take 50'
        size: 0
        title: 'DNAT Rule Hits - Source → Original → Translated'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
        gridSettings: {
          formatters: [
            { columnMatch: 'HitCount', formatter: 4, formatOptions: { palette: 'greenRed' } }
          ]
        }
      }
      name: 'dnat-hits'
    }
    {
      type: 1
      content: {
        json: '## 🔍 Recent Denied Traffic (Raw Logs)\nDetailed denied connection logs for troubleshooting.'
      }
      name: 'raw-header'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        query: 'AzureDiagnostics\n| where Category == "AzureFirewallNetworkRule"\n| where msg_s has "Deny"\n| project TimeGenerated, msg_s\n| order by TimeGenerated desc\n| take 100'
        size: 0
        title: 'Recent Denied Connections (Raw)'
        timeContextFromParameter: 'TimeRange'
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
        visualization: 'table'
      }
      name: 'raw-denied'
    }
  ]
  fallbackResourceIds: [
    logAnalyticsWorkspaceId
  ]
}

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, workbookName)
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: workbookName
    category: 'workbook'
    version: '1.0'
    serializedData: string(workbookContent)
    sourceId: logAnalyticsWorkspaceId
  }
}

output dashboardName string = dashboard.name
output dashboardId string = dashboard.id
output workbookName string = workbook.properties.displayName
output workbookId string = workbook.id
