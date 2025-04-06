param virtualNetworkName string
param addressPrefixes string
param location string = resourceGroup().location
param subnets array = []
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixes
      ]
    }
    subnets: subnets
  }
}

output id string = virtualNetwork.id 
output name string = virtualNetwork.name
 