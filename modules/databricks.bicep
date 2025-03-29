param location string = resourceGroup().location
param workspaceName string
param managementRGname string 

@allowed([
  'standard'
  'premium'
])
param sku string = 'premium'

param vnetId string
param publicSubnetName string
param privateSubnetName string


param disablePublicIp bool = true

@allowed([
  'Disabled'
  'Enabled'
])
param publicNetworkAccess string = 'Disabled'

@allowed(
  [
    'AllRules'
    'NoAzureDatabricksRules'
    'NoAzureServiceRules'
  ]
)
param requiredNsgRules string = 'NoAzureDatabricksRules'



resource workspace 'Microsoft.Databricks/workspaces@2024-05-01' = {
  name: workspaceName
  location: location
  tags: resourceGroup().tags
  sku: {
    name: sku
  }
  properties: {
    managedResourceGroupId: subscriptionResourceId('Microsoft.Resources/resourceGroups', managementRGname)
    parameters: {
      customVirtualNetworkId: {
        value: vnetId
      }
      customPublicSubnetName: {
        value: publicSubnetName
      }
      customPrivateSubnetName: {
        value: privateSubnetName
      }
      enableNoPublicIp: {
        value: disablePublicIp
      }
    }
    publicNetworkAccess: publicNetworkAccess
    requiredNsgRules: disablePublicIp ? 'NoAzureDatabricksRules' :  requiredNsgRules
  }
}


output id string = workspace.id 
