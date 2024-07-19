param location string = resourceGroup().location
@minLength(3)
@maxLength(10)
param prefix string
param tags object = {}

param sshAllowedSourceIp string = ''
param vmUsername string
param vmPublicKey string

var usablePrefix = toLower(trim(prefix))
var uniqueSuffix = uniqueString(resourceGroup().id, prefix)
var uniqueNameFormat = '${usablePrefix}-{0}-${uniqueSuffix}'

var vnetAddressPrefix = '10.180.190.0/24'
var vmSubnetName = '${usablePrefix}Subnet'
var vmSubnetAddressPrefix = '10.180.190.0/26'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: format(uniqueNameFormat, 'nsg')
  location: location
  tags: tags
  properties: {
    securityRules: empty(trim(sshAllowedSourceIp))
      ? []
      : [
          {
            name: 'Allow-ExternalInbound-SSH'
            properties: {
              priority: 100
              direction: 'Inbound'
              access: 'Allow'
              protocol: 'Tcp'
              sourceAddressPrefix: sshAllowedSourceIp
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '22'
            }
          }
        ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: format(uniqueNameFormat, 'vnet')
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
  resource vmSubnet 'subnets' existing = {
    name: vmSubnetName
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: format(uniqueNameFormat, 'pip')
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: format(uniqueNameFormat, 'nic')
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet::vmSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: format(uniqueNameFormat, 'vm')
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    osProfile: {
      computerName: vmUsername
      adminUsername: vmUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${vmUsername}/.ssh/authorized_keys'
              keyData: vmPublicKey
            }
          ]
        }
      }
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
