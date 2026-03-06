// ============================================================================
// ActiveMQ Container App Module
// ============================================================================
// Deploys Apache ActiveMQ as a Container App
// Port 61616 runs the STOMP transport (changed from default OpenWire).
// ACA TCP ingress only supports a single port, so we reconfigure ActiveMQ
// to serve STOMP on 61616 instead of the default OpenWire protocol.
// Port 8161 is the Web Management Console (HTTP) - not exposed via ACA.
// ============================================================================

param location string
param appName string
param acaEnvId string
param activeMqImage string
param tags object

resource activeMqApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: acaEnvId
    configuration: {
      ingress: {
        // TCP ingress — port 61616 speaks STOMP (reconfigured from default OpenWire)
        external: true   // Accessible from VNet (internal env = no public IP; Firewall DNAT reaches this)
        targetPort: 61616
        transport: 'tcp'
        exposedPort: 61616
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'activemq'
          image: activeMqImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'ACTIVEMQ_OPTS'
              value: '-Xms512m -Xmx1g'
            }
          ]
          // Reconfigure ActiveMQ to run STOMP on port 61616 instead of OpenWire.
          // ACA TCP ingress only supports a single exposed port, so we change
          // the transport connector to serve STOMP on the same port.
          // We remove the openwire connector and update the existing stomp
          // connector to listen on port 61616 instead of 61613.
          command: [
            '/bin/sh'
            '-c'
            'sed -i \'/<transportConnector name="openwire"/d\' /opt/activemq/conf/activemq.xml && sed -i \'s|<transportConnector name="stomp" uri="stomp://0.0.0.0:61613.*"/>|<transportConnector name="stomp" uri="stomp://0.0.0.0:61616?transport.closeAsync=false"/>|\' /opt/activemq/conf/activemq.xml && /opt/activemq/bin/activemq console'
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'tcp-connections'
            tcp: {
              metadata: {
                concurrentConnections: '100'
              }
            }
          }
        ]
      }
    }
  }
}

output activeMqFqdn string = activeMqApp.properties.configuration.ingress.fqdn
output activeMqAppName string = activeMqApp.name
