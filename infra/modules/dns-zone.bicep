// ============================================================================
// Azure Public DNS Zone Module
// ============================================================================
// Creates a Public DNS Zone with A records pointing to Azure Firewall's
// Public IP. This gives users a friendly hostname like:
//   broker.activemq-demo.com  →  <Firewall Public IP>
//
// NOTE: For this DNS to be publicly resolvable, you must delegate the domain's
//       NS records from your domain registrar to the Azure DNS nameservers
//       shown in the deployment outputs.
//
// For demo/internal use, you can add the hostname to /etc/hosts or use
// nslookup with Azure DNS nameservers directly.
// ============================================================================

param location string = 'global'  // DNS zones are always global
param dnsZoneName string
param firewallPublicIp string
param tags object

// Public DNS Zone
resource dnsZone 'Microsoft.Network/dnsZones@2023-07-01-preview' = {
  name: dnsZoneName
  location: location
  tags: tags
  properties: {
    zoneType: 'Public'
  }
}

// A Record: broker.<domain> → Firewall Public IP
resource brokerRecord 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: dnsZone
  name: 'broker'
  properties: {
    TTL: 300
    ARecords: [
      {
        ipv4Address: firewallPublicIp
      }
    ]
  }
}

// A Record: @ (root domain) → Firewall Public IP
resource rootRecord 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: dnsZone
  name: '@'
  properties: {
    TTL: 300
    ARecords: [
      {
        ipv4Address: firewallPublicIp
      }
    ]
  }
}

// A Record: console.<domain> → Firewall Public IP (for web console 8161)
resource consoleRecord 'Microsoft.Network/dnsZones/A@2023-07-01-preview' = {
  parent: dnsZone
  name: 'console'
  properties: {
    TTL: 300
    ARecords: [
      {
        ipv4Address: firewallPublicIp
      }
    ]
  }
}

output dnsZoneName string = dnsZone.name
output nameServers array = dnsZone.properties.nameServers
output brokerFqdn string = '${brokerRecord.name}.${dnsZoneName}'
output consoleFqdn string = '${consoleRecord.name}.${dnsZoneName}'
