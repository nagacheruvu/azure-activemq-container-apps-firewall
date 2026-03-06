// ============================================================================
// Hub-Spoke Architecture: Centralized Azure Firewall
// ============================================================================
// 
// Topology:
//   Hub VNet (10.0.0.0/16)  ←→ Peering ←→  Spoke VNet (10.1.0.0/16)
//       │                                        │
//   Azure Firewall                          Container Apps
//   (Central Egress)                        (ActiveMQ)
//
// Traffic Flow:
//   Inbound:  Client → FW PIP → DNAT → Peering → Spoke → ActiveMQ
//   Outbound: ActiveMQ → UDR → Peering → Hub FW → SNAT → Internet
//
// ============================================================================

targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name prefix')
param baseName string = 'activemq-mvp'

@description('Whitelisted source IPs allowed to connect to ActiveMQ')
param whitelistedIPs array = []

@description('ActiveMQ Docker image')
param activeMqImage string = 'rmohr/activemq:latest'

@description('Log Analytics retention in days')
param logRetentionDays int = 30

param tags object = {
  project: 'activemq-aca-firewall-mvp'
  environment: 'demo'
  topology: 'hub-spoke'
}

// ============================================================================
// Variables
// ============================================================================
var uniqueSuffix = uniqueString(resourceGroup().id)
var hubVnetName = '${baseName}-hub-vnet'
var spokeVnetName = '${baseName}-spoke-vnet'
var firewallName = '${baseName}-fw'
var firewallPipName = '${baseName}-fw-pip'
var firewallPolicyName = '${baseName}-fw-policy'
var logAnalyticsName = '${baseName}-law-${uniqueSuffix}'
var acaEnvName = '${baseName}-env'
var activeMqAppName = 'activemq'
var spokeRouteTableName = '${baseName}-spoke-rt'

// ============================================================================
// Module: Hub Networking (Hub VNet + Firewall Subnets)
// ============================================================================
module hubNet 'modules/hub-networking.bicep' = {
  name: 'hub-networking'
  params: {
    location: location
    hubVnetName: hubVnetName
    tags: tags
  }
}

// ============================================================================
// Module: Spoke Networking (Spoke VNet + ACA Subnet + Route Table)
// ============================================================================
module spokeNet 'modules/spoke-networking.bicep' = {
  name: 'spoke-networking'
  params: {
    location: location
    spokeVnetName: spokeVnetName
    routeTableName: spokeRouteTableName
    tags: tags
  }
}

// ============================================================================
// Module: VNet Peering (Hub ↔ Spoke)
// ============================================================================
module peering 'modules/vnet-peering.bicep' = {
  name: 'vnet-peering'
  params: {
    hubVnetName: hubVnetName
    spokeVnetName: spokeVnetName
    hubVnetId: hubNet.outputs.hubVnetId
    spokeVnetId: spokeNet.outputs.spokeVnetId
  }
}

// ============================================================================
// Module: Log Analytics
// ============================================================================
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  params: {
    location: location
    workspaceName: logAnalyticsName
    retentionDays: logRetentionDays
    tags: tags
  }
}

// ============================================================================
// Module: Azure Firewall (in Hub VNet)
// ============================================================================
module firewall 'modules/firewall.bicep' = {
  name: 'firewall'
  params: {
    location: location
    firewallName: firewallName
    firewallPipName: firewallPipName
    firewallPolicyName: firewallPolicyName
    firewallSubnetId: hubNet.outputs.firewallSubnetId
    firewallMgmtSubnetId: hubNet.outputs.firewallMgmtSubnetId
    whitelistedIPs: whitelistedIPs
    activeMqInternalIP: acaEnv.outputs.staticIp
    spokeAddressPrefix: '10.1.0.0/16'
    tags: tags
  }
}

// ============================================================================
// Module: Container Apps Environment (in Spoke VNet)
// ============================================================================
module acaEnv 'modules/aca-environment.bicep' = {
  name: 'aca-environment'
  params: {
    location: location
    envName: acaEnvName
    infrastructureSubnetId: spokeNet.outputs.acaSubnetId
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsSharedKey: logAnalytics.outputs.sharedKey
    tags: tags
  }
  dependsOn: [
    peering  // Peering must be established before ACA can route via Hub
  ]
}

// ============================================================================
// Module: ActiveMQ Container App
// ============================================================================
module containerApp 'modules/activemq-app.bicep' = {
  name: 'activemq-app'
  params: {
    location: location
    appName: activeMqAppName
    acaEnvId: acaEnv.outputs.envId
    activeMqImage: activeMqImage
    tags: tags
  }
}

// ============================================================================
// Module: Route Table Update (UDR → Hub Firewall)
// ============================================================================
module routeTableUpdate 'modules/spoke-route-update.bicep' = {
  name: 'spoke-route-update'
  params: {
    routeTableName: spokeRouteTableName
    hubFirewallPrivateIp: firewall.outputs.firewallPrivateIp
  }
}

// ============================================================================
// Outputs
// ============================================================================
output firewallPublicIp string = firewall.outputs.firewallPublicIp
output firewallPrivateIp string = firewall.outputs.firewallPrivateIp
output hubVnetName string = hubNet.outputs.hubVnetName
output spokeVnetName string = spokeNet.outputs.spokeVnetName
output acaEnvironmentName string = acaEnv.outputs.envName
output activeMqFqdn string = containerApp.outputs.activeMqFqdn
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
