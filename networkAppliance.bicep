targetScope = 'subscription'
param currentTime string = utcNow()
param hubNetwork object
param dnsResolver object 
param vpnGateway object 
param location string = 'eastus'


var tag = {
  project: 'dbx-private'
  env: 'dev'
}

resource hub_network_rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'hub-network-rg'
  location: location
  tags: tag
}

module hubVnet 'modules/vnet.bicep' = {
  name: 'hubnetwork-${currentTime}'
  scope: resourceGroup(hub_network_rg.name)
  params: {
    addressPrefixes: hubNetwork.hubnetworkAddressRange
    virtualNetworkName: hubNetwork.name
    subnets: [
      {
        name: 'dns-resolver-subnet'
        properties:{
          addressPrefix: dnsResolver.dnsResolverSubnetRange
        }
      }
      {
        name: 'GatewaySubnet'
        properties:{
          addressPrefix: vpnGateway.gatewaySubnetRange
        }
      }
    ]
  }
}




module privateDNSResolver 'modules/privateDNSResolver.bicep' = {
  scope: resourceGroup(hub_network_rg.name)
  name: 'privateDNSResolver-${currentTime}'
  params:{
    dnsResolverName: dnsResolver.name
    dnsResolverSubnetId: '${subscription().id}/resourceGroups/${hub_network_rg.name}/providers/Microsoft.Network/virtualNetworks/${hubVnet.outputs.name}/subnets/dns-resolver-subnet'
    inboundStaticIp: dnsResolver.dnsInboundStaticIp
    virtualNetworkName: hubVnet.outputs.name
  }
}


module vpngtw 'modules/p2sVpnGatewayAAD.bicep' = {
  scope: resourceGroup(hub_network_rg.name)
  name: 'p2sVPNGatewayAAD-${currentTime}'
  params: {
    gatewayName: vpnGateway.name
    gatewaySubnetId: '${subscription().id}/resourceGroups/${hub_network_rg.name}/providers/Microsoft.Network/virtualNetworks/${hubVnet.outputs.name}/subnets/GatewaySubnet'
  }
}
