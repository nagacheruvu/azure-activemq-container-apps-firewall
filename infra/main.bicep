// ============================================================================
// ActiveMQ on Azure Container Apps with Azure Firewall Egress Control
// ============================================================================
// Architecture:
//   Client → Azure Firewall (Public IP) → VNet → Container Apps Env → ActiveMQ
//   Azure Firewall DNAT rules forward whitelisted TCP traffic to ActiveMQ
//   Azure Firewall Network rules control egress SNAT
// ============================================================================

targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name prefix for resources')
param baseName string = 'activemq-mvp'

@description('Whitelisted source IP addresses allowed to connect to ActiveMQ')
param whitelistedIPs array = []

@description('ActiveMQ Docker image')
param activeMqImage string = 'rmohr/activemq:latest'

@description('Log Analytics workspace retention in days')
param logRetentionDays int = 30

@description('Tags for all resources')
param tags object = {
  project: 'activemq-aca-firewall-mvp'
  environment: 'demo'
}

// ============================================================================
// Variables
// ============================================================================
var uniqueSuffix = uniqueString(resourceGroup().id)
var vnetName = '${baseName}-vnet'
var firewallName = '${baseName}-fw'
var firewallPipName = '${baseName}-fw-pip'
var firewallPolicyName = '${baseName}-fw-policy'
var logAnalyticsName = '${baseName}-law-${uniqueSuffix}'
var acaEnvName = '${baseName}-env'
var activeMqAppName = 'activemq'
var routeTableName = '${baseName}-rt'

// ============================================================================
// Module: Networking (VNet, Subnets, Route Table)
// ============================================================================
module networking 'modules/networking.bicep' = {
  name: 'networking'
  params: {
    location: location
    vnetName: vnetName
    routeTableName: routeTableName
    tags: tags
  }
}

// ============================================================================
// Module: Azure Firewall
// ============================================================================
module firewall 'modules/firewall.bicep' = {
  name: 'firewall'
  params: {
    location: location
    firewallName: firewallName
    firewallPipName: firewallPipName
    firewallPolicyName: firewallPolicyName
    firewallSubnetId: networking.outputs.firewallSubnetId
    firewallMgmtSubnetId: networking.outputs.firewallMgmtSubnetId
    whitelistedIPs: whitelistedIPs
    activeMqInternalIP: acaEnv.outputs.staticIp
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: tags
  }
}

// ============================================================================
// Module: Log Analytics
// ============================================================================
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'logAnalytics'
  params: {
    location: location
    workspaceName: logAnalyticsName
    retentionDays: logRetentionDays
    tags: tags
  }
}

// ============================================================================
// Module: Container Apps Environment
// ============================================================================
module acaEnv 'modules/aca-environment.bicep' = {
  name: 'acaEnvironment'
  params: {
    location: location
    envName: acaEnvName
    infrastructureSubnetId: networking.outputs.acaSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsSharedKey: logAnalytics.outputs.sharedKey
    tags: tags
  }
}

// ============================================================================
// Module: ActiveMQ Container App
// ============================================================================
module containerApp 'modules/activemq-app.bicep' = {
  name: 'activeMqApp'
  params: {
    location: location
    appName: activeMqAppName
    acaEnvId: acaEnv.outputs.envId
    activeMqImage: activeMqImage
    tags: tags
  }
}

// ============================================================================
// Module: Route Table Update (UDR to force traffic through Firewall)
// ============================================================================
module routeTableUpdate 'modules/route-table-update.bicep' = {
  name: 'routeTableUpdate'
  params: {
    routeTableName: routeTableName
    firewallPrivateIp: firewall.outputs.firewallPrivateIp
  }
}

// ============================================================================
// Module: Azure Monitor Dashboard & Workbook
// ============================================================================
module monitorDashboard 'modules/monitor-dashboard.bicep' = {
  name: 'monitorDashboard'
  params: {
    location: location
    dashboardName: '${baseName}-dashboard'
    workbookName: 'ActiveMQ Firewall Traffic Workbook'
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    firewallResourceId: firewall.outputs.firewallResourceId
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================
output firewallPublicIp string = firewall.outputs.firewallPublicIp
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output acaEnvironmentName string = acaEnv.outputs.envName
output activeMqFqdn string = containerApp.outputs.activeMqFqdn
output vnetName string = networking.outputs.vnetName
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId

// Dashboard outputs
output dashboardName string = monitorDashboard.outputs.dashboardName
output workbookName string = monitorDashboard.outputs.workbookName
