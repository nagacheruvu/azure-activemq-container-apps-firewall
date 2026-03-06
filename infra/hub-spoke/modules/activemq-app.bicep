// ============================================================================
// ActiveMQ Container App — TCP ingress on port 61616
// ============================================================================

@description('Location')
param location string

@description('App name')
param appName string

@description('Container Apps environment resource ID')
param acaEnvId string

@description('ActiveMQ Docker image')
param activeMqImage string = 'rmohr/activemq:latest'

param tags object = {}

resource activeMq 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: acaEnvId
    configuration: {
      ingress: {
        external: true           // Exposed within VNet (internal env = no public IP)
        targetPort: 61616
        transport: 'tcp'
        exposedPort: 61616
      }
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
          command: [
            '/bin/bash'
            '-c'
            'sed -i "s|tcp://0.0.0.0:61616|stomp://0.0.0.0:61616|" /opt/activemq/conf/activemq.xml && /opt/activemq/bin/activemq console'
          ]
          env: [
            {
              name: 'ACTIVEMQ_OPTS'
              value: '-Xms512m -Xmx1g'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

output activeMqFqdn string = activeMq.properties.configuration.ingress.fqdn
output appName string = activeMq.name
