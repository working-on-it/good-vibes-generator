param resourceLocation string = resourceGroup().location
@minLength(3)
@maxLength(12)
param azureResourcePrefix string
param storageAccountName string

var applicationInsightsName = '${toLower(azureResourcePrefix)}-insights'
var appServicePlanName = '${toLower(azureResourcePrefix)}-plan'
var botServicesName = '${toLower(azureResourcePrefix)}-bot'
var cosmosName = '${toLower(azureResourcePrefix)}-cosmos'
var cosmosDatabaseName = 'good-vibes-generator'
var functionAppName = '${toLower(azureResourcePrefix)}-func'
var keyVaultName = '${toLower(azureResourcePrefix)}-kv'
var logAnalyticsWorkspaceName = '${toLower(azureResourcePrefix)}-logs'
var userAssignedManagedIdentityName = '${toLower(azureResourcePrefix)}-mi'

var botServicesEndpoint = 'https://${toLower(functionAppName)}.azurewebsites.net/api/messages'
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var cosmosContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5bd9cd88-fe45-4216-938b-f97437e15450')
var storageBlobDataOwnerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')

resource userAssignedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: userAssignedManagedIdentityName
  location: resourceLocation
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: cosmosName
  location: resourceLocation
  kind: 'GlobalDocumentDB'
  properties: {
    publicNetworkAccess: 'Enabled'
    databaseAccountOfferType: 'Standard'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    ipRules: []
    locations: [
      {
        locationName: resourceLocation
      }
    ]
    backupPolicy: {
      type: 'Continuous'
    }
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  name: '${cosmosAccount.name}/${toLower(cosmosDatabaseName)}'
  properties: {
    resource: {
      id: cosmosDatabaseName
    }
  }
}

resource cosmosContainerConfig 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  parent: cosmosDatabase
  name: 'config'
  properties: {
    resource: {
      id: 'config'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

resource cosmosContainerConversations 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-10-15' = {
  parent: cosmosDatabase
  name: 'conversations'
  properties: {
    resource: {
      id: 'conversations'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: resourceLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: resourceLocation
  properties: any({
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: applicationInsightsName
  location: resourceLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
  }
}

resource botServices 'Microsoft.BotService/botServices@2021-05-01-preview' = {
  name: botServicesName
  location: 'global'
  sku: {
    name: 'S1'
  }
  kind: 'azurebot'
  properties: {
    displayName: 'Good Vibes'
    iconUrl: 'https://docs.botframework.com/static/devportal/client/images/bot-framework-default.png'
    endpoint: botServicesEndpoint
    msaAppId: userAssignedManagedIdentity.properties.clientId
    msaAppTenantId: tenant().tenantId
    msaAppType: 'UserAssignedMSI'
    msaAppMSIResourceId: userAssignedManagedIdentity.id
    luisAppIds: []
    isStreamingSupported: true
    schemaTransformationVersion: '1.3'
  }
}

resource botServicesMsTeamsChannel 'Microsoft.BotService/botServices/channels@2021-05-01-preview' = {
  parent: botServices
  name: 'MsTeamsChannel'
  location: 'global'
  properties: {
    properties: {
      enableCalling: false
      incomingCallRoute: 'graphPma'
      isEnabled: true
      acceptedTerms: true
    }
    channelName: 'MsTeamsChannel'
    location: 'global'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: resourceLocation
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
  }
  resource appInsightsInstrumentationKeySecret 'secrets' = {
    name: 'appInsightsInstrumentationKey'
    properties: {
      value: applicationInsights.properties.InstrumentationKey
    }
  }
  resource appInsightsConnectionStringSecret 'secrets' = {
    name: 'appInsightsConnectionString'
    properties: {
      value: applicationInsights.properties.ConnectionString
    }
  }
  resource azureWebJobsStorageSecret 'secrets' = {
    name: 'azureWebJobsStorage'
    properties: {
      value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
    }
  }
  resource cosmosDbDatabaseSecret 'secrets' = {
    name: 'cosmosDbDatabase'
    properties: {
      value: cosmosDatabaseName
    }
  }
  resource cosmosDbUriSecret 'secrets' = {
    name: 'cosmosDbUri'
    properties: {
      value: cosmosAccount.properties.documentEndpoint
    }
  }
  resource microsoftAppIdSecret 'secrets' = {
    name: 'microsoftAppId'
    properties: {
      value: userAssignedManagedIdentity.properties.clientId
    }
  }
  resource microsoftAppTenantIdSecret 'secrets' = {
    name: 'microsoftAppTenantId'
    properties: {
      value: tenant().tenantId
    }
  }
}

resource keyVaultFunctionAppAadRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, functionApp.name, keyVaultSecretsUserRole)
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}

resource cosmosFunctionAppAadRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(cosmosAccount.id, functionApp.name, cosmosContributorRole)
  scope: cosmosAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: cosmosContributorRole
  }
}

resource storageFunctionAppAadRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, functionApp.name, storageBlobDataOwnerRole)
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataOwnerRole
  }
}

resource cosmosDataContributorRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-10-15' existing = {
  name: '00000000-0000-0000-0000-000000000002'
  parent: cosmosAccount
}

resource cosmosFunctionAppSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-10-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionApp.name, cosmosDataContributorRole.id)
  properties: {
    roleDefinitionId: cosmosDataContributorRole.id
    principalId: functionApp.identity.principalId
    scope: cosmosAccount.id
  }
}

resource appServicePlan 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServicePlanName
  location: resourceLocation
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: resourceLocation
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedManagedIdentity.id}': {}
    }
  }
  properties: {
    enabled: true
    keyVaultReferenceIdentity: 'SystemAssigned'
    serverFarmId: appServicePlan.id
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'Node|14'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::appInsightsInstrumentationKeySecret.name})'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::appInsightsConnectionStringSecret.name})'
        }
        {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::azureWebJobsStorageSecret.name})'
        }
        {
          name: 'CosmosDbDatabase'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::cosmosDbDatabaseSecret.name})'
        }
        {
          name: 'CosmosDbUri'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::cosmosDbUriSecret.name})'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'MicrosoftAppId'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::microsoftAppIdSecret.name})'
        }
        {
          name: 'MicrosoftAppTenantId'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::microsoftAppTenantIdSecret.name})'
        }
        {
          name: 'MicrosoftAppType'
          value: 'UserAssignedMsi'
        }
      ]
    }
  }
}
