param subnetName string
param subnetRange string
param vnetName string
param delegations array = []
param serviceEndpoints array =[]
param routeTable string = ''
param networkSecurityGroupID string = ''
param natGatewayId string = ''
param privateLinkServiceNetworkPolicies string = 'Disabled'

resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  name: vnetName
}


resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetRange
    delegations: [for delegation in delegations :{
        name: delegation
        properties: {
          serviceName: delegation
        }
      }]

    serviceEndpoints: [for serviceEndpoint in serviceEndpoints :{
        service: serviceEndpoint
      }]
    
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies

    routeTable : routeTable != '' ? {
      id: routeTable
    } : null

    networkSecurityGroup: networkSecurityGroupID != '' ? {
      id: networkSecurityGroupID
    } : null
    natGateway: natGatewayId != ''? {
      id: natGatewayId
    } : null
  }
}

output id string = subnet.id
output name string = subnet.name
