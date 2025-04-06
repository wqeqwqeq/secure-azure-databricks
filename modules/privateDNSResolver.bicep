

param virtualNetworkName string
param dnsResolverSubnetId string
param dnsResolverName string = 'dns-resolver'
param inboundStaticIp string
param location string = resourceGroup().location


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: virtualNetworkName
}



resource dnsResolvers 'Microsoft.Network/dnsResolvers@2023-07-01-preview' = {
  name: dnsResolverName
  location: location
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2023-07-01-preview' = {
  parent: dnsResolvers
  name: 'inboundDNSResolver'
  location: location
  properties: {
    ipConfigurations: [
      {
        subnet: {
          id: dnsResolverSubnetId
        }
        privateIpAddress: inboundStaticIp
        privateIpAllocationMethod: 'Static'
      }
    ]
  }
}
