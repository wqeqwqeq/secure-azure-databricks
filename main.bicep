targetScope = 'subscription'
param location string = 'eastus'
param currentTime string = utcNow()


var dataPlaneSubent  = [
  {
    name: 'privateEndpoint-subnet'
    range: '10.0.0.0/26'
    nsgEnabled: false
  }
  {
    name: 'dbx-private-public-subnet'
    range: '10.0.1.0/26'
    nsgEnabled: true
    delegations: ['Microsoft.Databricks/workspaces']
  }
  {
    name: 'dbx-private-private-subnet'
    range: '10.0.2.0/26'
    nsgEnabled: true
    delegations: ['Microsoft.Databricks/workspaces']
  }

]
var transitPlaneSubent  = [
  {
    name: 'privateEndpoint-subnet'
    range: '10.1.0.0/26'
    nsgEnabled: false
  }
  {
    name: 'dbx-webauth-public-subnet'
    range: '10.1.1.0/26'
    nsgEnabled: true
    delegations: ['Microsoft.Databricks/workspaces']
  }
  {
    name: 'dbx-webauth-private-subnet'
    range: '10.1.2.0/26'
    nsgEnabled: true
    delegations: ['Microsoft.Databricks/workspaces']
  }

]

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
    addressPrefixes: '10.0.0.0/20' 
    virtualNetworkName: 'dbx-data-plane-network'
  }
}

module data_transit_network 'modules/vnet.bicep' = {
  name: 'data-transit-network-${currentTime}'
  scope: resourceGroup(resourceGroups.network)
  params: {
    addressPrefixes: '10.1.0.0/20' 
    virtualNetworkName: 'dbx-transit-plane-network'
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


@batchSize(1)
module subnet_data_plane 'modules/subnet.bicep' = [for subnet in dataPlaneSubent : { 
  scope: resourceGroup(resourceGroups.network)
  name: 'subnet-data-plane-${subnet.name}-${currentTime}'
  params: {
    vnetName: data_plane_network.outputs.name
    subnetName: subnet.name
    subnetRange: subnet.range 
    delegations: subnet.?delegations?? []
    networkSecurityGroupID: subnet.nsgEnabled ? nsg.outputs.nsgId : ''
    natGatewayId: subnet.?natGatewayEnabled?? ''  // to be implemented
    routeTable: subnet.?routeTableEnabled?? '' // to be implemented
  }
}
]

@batchSize(1)
module subnet_transit_plane 'modules/subnet.bicep' = [for subnet in transitPlaneSubent : { 
  scope: resourceGroup(resourceGroups.network)
  name: 'subnet-transit-plane-${subnet.name}-${currentTime}'
  params: {
    vnetName: data_transit_network.outputs.name
    subnetName: subnet.name
    subnetRange: subnet.range 
    delegations: subnet.?delegations?? []
    networkSecurityGroupID: subnet.nsgEnabled ? nsg.outputs.nsgId : ''
    natGatewayId: subnet.?natGatewayEnabled?? ''  // to be implemented
    routeTable: subnet.?routeTableEnabled?? '' // to be implemented
  }
}
]






module dns_data_plane 'modules/dns.bicep' = {
  name: 'private-dns-data-${currentTime}'
  scope: resourceGroup(resourceGroups.data)
  params:{
    privateDnsZoneName: 'privatelink.azuredatabricks.net'
    vnetId: data_plane_network.outputs.id
  }
}

// dns in transit network 
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
    privateSubnetName: 'dbx-private-private-subnet'
    publicSubnetName: 'dbx-private-public-subnet'
    publicNetworkAccess: 'Disabled'
  }
  dependsOn:[subnet_data_plane]
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
    subnetId: subnet_data_plane[0].outputs.id
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
    subnetId: subnet_transit_plane[0].outputs.id
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
    privateSubnetName: 'dbx-webauth-private-subnet'
    publicSubnetName: 'dbx-webauth-public-subnet'
    publicNetworkAccess: 'Disabled'
  }
  dependsOn:[subnet_transit_plane]
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
    subnetId: subnet_transit_plane[0].outputs.id
    targetResourceId: dbxWebAuth.outputs.id
  }
}


