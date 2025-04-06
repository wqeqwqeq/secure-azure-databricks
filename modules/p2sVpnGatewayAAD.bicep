
@description('Name for the new gateway')
param gatewayName string

@description('Location for the resources')
param location string = resourceGroup().location

param gatewaySubnetId string

@description('Name for public IP resource used for the new azure gateway')
param gatewayPublicIPName string = 'vpngtw-pip'

@description('The SKU of the Gateway. This must be either Standard or HighPerformance to work with OpenVPN')
param gatewaySku object = {
      name: 'VpnGw1'
      tier: 'VpnGw1'
}



@description('The IP address range from which VPN clients will receive an IP address when connected. Range specified must not overlap with on-premise network')
param vpnClientAddressPool string = '172.16.201.0/24'




var tenantId = subscription().tenantId
var tenant = uri(environment().authentication.loginEndpoint, tenantId)
var issuer = 'https://sts.windows.net/${tenantId}/'



resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: gatewayPublicIPName
  location: location
  sku:{
    name:'Standard'
    tier:'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}



resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: gatewayName
  location: location
  properties: {
    activeActive: false
    enableBgp: false
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: gatewaySku
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
      vpnAuthenticationTypes: [
        'AAD'
      ]
      aadTenant: '${tenant}/'
      aadAudience: 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8'
      aadIssuer: issuer
    }
  }
}

