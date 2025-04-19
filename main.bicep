targetScope = 'subscription'
param location string = 'eastus'
param currentTime string = utcNow()
param dataPlaneNetwork object
param transitPlaneNetwork object

var resourceGroups = {
  network: dbx_network_rg.name
  transit: dbx_transit_rg.name
  data: dbx_data_plane_rg.name
} 

var databricksName = 'dbx-Private'
var databricksWebAuthName = 'dbx-webauth'

var tag = {
  project: 'dbx-private'
  env: 'dev'
}

resource dbx_data_plane_rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'dbx-data-plane'
  location: location
  tags: tag
}

resource dbx_network_rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'dbx-network'
  location: location
  tags: tag
}

resource dbx_transit_rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'dbx-transit'
  location: location
  tags: tag
}

module data_plane_network 'modules/vnet.bicep' = {
  name: 'data-plane-network-${currentTime}'
  scope: resourceGroup(resourceGroups.network)
  params: {
    addressPrefixes: dataPlaneNetwork.addressSpace
    virtualNetworkName: dataPlaneNetwork.name
    subnets: [
      {
        name: dataPlaneNetwork.subnets.peSubnet.name
        properties: {
          addressPrefix: dataPlaneNetwork.subnets.peSubnet.range
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: dataPlaneNetwork.subnets.dbxPrivateSubnet.name
        properties: {
          addressPrefix: dataPlaneNetwork.subnets.dbxPrivateSubnet.range
          delegations: [
            {
              name: 'Microsoft.Databricks/workspaces'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.outputs.nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          routeTable: dataPlaneNetwork.subnets.dbxPrivateSubnet.routeTableEnabled ? {
            id: 'to be implemented'
          } : null
          natGateway: dataPlaneNetwork.subnets.dbxPrivateSubnet.natGatewayEnabled ? {
            id: 'to be implemented'
          } : null
        }
      }
      {
        name: dataPlaneNetwork.subnets.dbxPublicSubnet.name
        properties: {
          addressPrefix: dataPlaneNetwork.subnets.dbxPublicSubnet.range
          delegations: [
            {
              name: 'Microsoft.Databricks/workspaces'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.outputs.nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          routeTable: dataPlaneNetwork.subnets.dbxPublicSubnet.routeTableEnabled ? {
            id: 'to be implemented'
          } : null
          natGateway: dataPlaneNetwork.subnets.dbxPublicSubnet.natGatewayEnabled ? {
            id: 'to be implemented'
          } : null
        }
      }
    ]
  }
}

module data_transit_network 'modules/vnet.bicep' = {
  name: 'data-transit-network-${currentTime}'
  scope: resourceGroup(resourceGroups.network)
  params: {
    addressPrefixes: transitPlaneNetwork.addressSpace
    virtualNetworkName: transitPlaneNetwork.name
    subnets: [
      {
        name: transitPlaneNetwork.subnets.peSubnet.name
        properties: {
          addressPrefix: transitPlaneNetwork.subnets.peSubnet.range
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: transitPlaneNetwork.subnets.dbxPrivateSubnet.name
        properties: {
          addressPrefix: transitPlaneNetwork.subnets.dbxPrivateSubnet.range
          delegations: [
            {
              name: 'Microsoft.Databricks/workspaces'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.outputs.nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          routeTable: transitPlaneNetwork.subnets.dbxPrivateSubnet.routeTableEnabled ? {
            id: 'to be implemented'
          } : null
          natGateway: transitPlaneNetwork.subnets.dbxPrivateSubnet.natGatewayEnabled ? {
            id: 'to be implemented'
          } : null
        }
      }
      {
        name: transitPlaneNetwork.subnets.dbxPublicSubnet.name
        properties: {
          addressPrefix: transitPlaneNetwork.subnets.dbxPublicSubnet.range
          delegations: [
            {
              name: 'Microsoft.Databricks/workspaces'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.outputs.nsgId
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          routeTable: transitPlaneNetwork.subnets.dbxPublicSubnet.routeTableEnabled ? {
            id: 'to be implemented'
          } : null
          natGateway: transitPlaneNetwork.subnets.dbxPublicSubnet.natGatewayEnabled ? {
            id: 'to be implemented'
          } : null
        }
      }
    ]
  }
}

module nsg 'modules/nsg.bicep' = {
  name: 'nsg-${currentTime}'
  scope: resourceGroup(resourceGroups.network)
  params: {
    nsgName: 'dbx-private-nsg'
    isDbxNsg: true
  }
}

module dns_data_plane 'modules/dns.bicep' = {
  name: 'private-dns-data-${currentTime}'
  scope: resourceGroup(resourceGroups.data)
  params:{
    privateDnsZoneName: 'privatelink.azuredatabricks.net'
    vnetId: data_plane_network.outputs.id
  }
}

module dns_transit_plane 'modules/dns.bicep' = {
  name: 'private-dns-transit-${currentTime}'
  scope: resourceGroup(resourceGroups.transit)
  params:{
    privateDnsZoneName: 'privatelink.azuredatabricks.net'
    vnetId: data_transit_network.outputs.id
  }
}

module dbxWorkspace 'modules/databricks.bicep' = {
  name: 'dbxWorkspace-${currentTime}'
  scope: resourceGroup(resourceGroups.data)
  params: {
    workspaceName: databricksName
    managementRGname: '${databricksName}-ManagementRG'
    vnetId: data_plane_network.outputs.id
    privateSubnetName: dataPlaneNetwork.subnets.dbxPrivateSubnet.name
    publicSubnetName: dataPlaneNetwork.subnets.dbxPublicSubnet.name
    publicNetworkAccess: 'Disabled'
  }
}

module dbxBackendPE 'modules/privatEndpoint.bicep' = {
  scope: resourceGroup(resourceGroups.data)
  name: 'dbx-private-backend-pe-${currentTime}'
  params: {
    groupIds: ['databricks_ui_api']
    privateDnsZoneConfigs: [{
      name: 'default'
      properties:{
        privateDnsZoneId: dns_data_plane.outputs.privateDnsZoneId
      }
    }]
    privateEndpointName: 'dbx-private-backend-pe'
    subnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroups.network}/providers/Microsoft.Network/virtualNetworks/${dataPlaneNetwork.name}/subnets/${dataPlaneNetwork.subnets.peSubnet.name}'
    targetResourceId: dbxWorkspace.outputs.id
  }
}

// pe in transit network
module dbxFrontendPE 'modules/privatEndpoint.bicep' = {
  scope: resourceGroup(resourceGroups.transit)
  name: 'dbx-private-frontend-pe-${currentTime}'
  params: {
    groupIds: ['databricks_ui_api']
    privateDnsZoneConfigs: [{
      name: 'default'
      properties:{
        privateDnsZoneId: dns_transit_plane.outputs.privateDnsZoneId
      }
    }]
    privateEndpointName: 'dbx-private-frontend-pe'
    subnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroups.network}/providers/Microsoft.Network/virtualNetworks/${transitPlaneNetwork.name}/subnets/${transitPlaneNetwork.subnets.peSubnet.name}'
    targetResourceId: dbxWorkspace.outputs.id
  }
  dependsOn: [dbxBackendPE]
}

module dbxWebAuth 'modules/databricks.bicep' = {
  name: 'dbxWebAuth-${currentTime}'
  scope: resourceGroup(resourceGroups.transit)
  params: {
    workspaceName: databricksWebAuthName
    managementRGname: '${databricksWebAuthName}-ManagementRG'
    vnetId: data_transit_network.outputs.id
    privateSubnetName: transitPlaneNetwork.subnets.dbxPrivateSubnet.name
    publicSubnetName: transitPlaneNetwork.subnets.dbxPublicSubnet.name
    publicNetworkAccess: 'Disabled'
  }
}

module dbxWebAuthPE 'modules/privatEndpoint.bicep' = {
  scope: resourceGroup(resourceGroups.transit)
  name: 'dbx-webauth-pe-${currentTime}'
  params: {
    groupIds: ['browser_authentication']
    privateDnsZoneConfigs: [{
      name: 'default'
      properties:{
        privateDnsZoneId: dns_transit_plane.outputs.privateDnsZoneId
      }
    }]
    privateEndpointName: 'dbx-webauth-pe'
    subnetId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroups.network}/providers/Microsoft.Network/virtualNetworks/${transitPlaneNetwork.name}/subnets/${transitPlaneNetwork.subnets.peSubnet.name}'
    targetResourceId: dbxWebAuth.outputs.id
  }
}


