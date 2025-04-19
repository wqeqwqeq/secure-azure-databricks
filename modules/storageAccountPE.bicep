param storageAccountName string
param location string = resourceGroup().location
param vnetName string
param subnetName string
param tags object = resourceGroup().tags



resource vnet 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  scope: resourceGroup('dbx-network')
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: subnetName
  parent: vnet
}

// Create storage account with hierarchical namespace enabled
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}

// Create private endpoint for blob
module blobPrivateEndpoint 'privatEndpoint.bicep' = {
  name: 'blob-pe'
  params: {
    privateEndpointName: '${storageAccountName}-blob-pe'
    subnetId: subnet.id
    targetResourceId: storageAccount.id
    groupIds: ['blob']
    privateDnsZoneConfigs: [{
      name: 'default'
      properties: {
        privateDnsZoneId: blobDnsZone.outputs.privateDnsZoneId
      }
    }]
  }
}

// Create private endpoint for dfs
module dfsPrivateEndpoint 'privatEndpoint.bicep' = {
  name: 'dfs-pe'
  params: {
    privateEndpointName: '${storageAccountName}-dfs-pe'
    subnetId: subnet.id
    targetResourceId: storageAccount.id
    groupIds: ['dfs']
    privateDnsZoneConfigs: [{
      name: 'default'
      properties: {
        privateDnsZoneId: dfsDnsZone.outputs.privateDnsZoneId
      }
    }]
  }
}

// Create private DNS zone for blob
module blobDnsZone 'dns.bicep' = {
  name: 'blob-dns'
  params: {
    vnetId: vnet.id
    privateDnsZoneName: 'privatelink.blob.core.windows.net'
  }
}

// Create private DNS zone for dfs
module dfsDnsZone 'dns.bicep' = {
  name: 'dfs-dns'
  params: {
    vnetId: vnet.id
    privateDnsZoneName: 'privatelink.dfs.core.windows.net'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name 
