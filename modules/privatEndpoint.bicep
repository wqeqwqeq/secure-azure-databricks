param privateEndpointName string
param location string = resourceGroup().location
param subnetId string
param targetResourceId string
param groupIds array 
param privateDnsZoneConfigs array

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: groupIds
        }
      }
    ]
    customNetworkInterfaceName: '${privateEndpointName}-nic'
  }
}


resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-03-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: privateDnsZoneConfigs
  }
}
