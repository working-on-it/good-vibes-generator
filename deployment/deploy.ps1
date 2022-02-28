[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Location,
    [Parameter(Mandatory = $true)]
    [string]
    $SubscriptionId,
    [ValidateLength(3, 12)]
    [Parameter(Mandatory = $true)]
    [string]
    $AzureResourcePrefix,
    [Parameter(Mandatory = $false)]
    [string]
    $ResourceGroupName = "GoodVibesGenerator"
)

# Ya get 'me'?
$me = az ad signed-in-user show | ConvertFrom-Json

# Validate subscription
Write-Host "Validating subscription... "
if ($SubscriptionId -ne "") {
    az account set -s $SubscriptionId
    if (!$?) { 
        Write-Error "Unable to select $SubscriptionId as the active subscription"
        exit 1
    }
    Write-Host "Active subscription set to $SubscriptionId" -ForegroundColor Green
}
else {
    $Subscription = az account show | ConvertFrom-Json
    $SubscriptionId = $Subscription.id
    $SubscriptionName = $Subscription.name
    Write-Host "Active subscription is $SubscriptionId ($SubscriptionName)" -ForegroundColor Green
}

# Validate location
Write-Host "Validating deployment location... "
$ValidateLocation = az account list-locations --query "[?name=='$Location']" | ConvertFrom-Json
if ($ValidateLocation.Count -eq 0) {
    Write-Error "The location provided is not valid, the available locations for your account are:"
    az account list-locations --query [].name
    exit 1
}
Write-Host "Location $Location is valid" -ForegroundColor Green

# Create resource group
Write-Host "Creating resource group (if it doesn't already exist)... "
az group create `
    --name $ResourceGroupName `
    --location $Location
Write-Host "$ResourceGroupName created" -ForegroundColor Green   
if (!$?) { 
    Write-Error "Unable to create resource group"
    exit 1
}
Write-Host "Resource group created/exists" -ForegroundColor Green

# Check user has permissions to resource group
Write-Host "Ensuring current user has Contributor permissions to resource group $ResourceGroupName..."
$roleAssignments = az role assignment list --all --assignee $me.objectId --query "[?resourceGroup=='$ResourceGroupName' && roleDefinitionName=='Contributor'].roleDefinitionName" | ConvertFrom-Json
if ($roleAssignments.Count -eq 0) {
    Write-Host "Current user does not have Contributor permissions to $ResourceGroupName resource group, attempting to assign permissions..."
    az role assignment create `
        --assignee $me.objectId `
        --role contributor `
        --resource-group $ResourceGroupName
}
Write-Host "Current user has Contributor permissions to resource group $ResourceGroupName" -ForegroundColor Green

# Deploy resources in Resource Group
Write-Host "Deploying Azure resources to resource group $ResourceGroupName..."
$DeployTimestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdTHmZ")
# Generate storage account name separately as it has to conform to certain conventions
$StorageAccountName = ($azureResourcePrefix -replace '[^a-zA-Z0-9]', '').toLower() + "storage"
az deployment group create `
    --name "GVG-$DeployTimestamp" `
    --resource-group $ResourceGroupName `
    --template-file ./bicep/gvg-root.bicep `
    --parameters azureResourcePrefix=$AzureResourcePrefix `
    storageAccountName=$StorageAccountName `
    --verbose
if (!$?) { 
    Write-Error "An error occured during the ARM deployment"
    exit 1
}
Write-Host "Azure resources deployed successfully" -ForegroundColor Green

# Deploy 'zip' in to Function App
# Grant current user data access to storage account
Write-Host "Ensuring current user has Storage Blob Data Contributor permissions to storage account $StorageAccountName..."
$StorageAccountScope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"
$StorageAccountRole = "Storage Blob Data Contributor"
$roleAssignments = az role assignment list --all --assignee $me.objectId --query "[?scope=='$StorageAccountScope' && roleDefinitionName=='$StorageAccountRole'].roleDefinitionName" | ConvertFrom-Json
if ($roleAssignments.Count -eq 0) {
    Write-Host "Current user does not have Storage Blob Data Contributor permissions to storage account $StorageAccountName, attempting to assign permissions..."
    az role assignment create `
        --assignee $me.objectId `
        --role $StorageAccountRole `
        --scope $StorageAccountScope
    Write-Host "Waiting for a minute for permissions to take effect..."
    Start-Sleep -Seconds 60
}
Write-Host "Current user has Storage Blob Data Contributor permissions to storage account $StorageAccountName" -ForegroundColor Green

Write-Host "Creating a storage container for function app releases..."
# Create container in storage for releases
$ReleaseContainerName = "function-releases"
az storage container create `
    --account-name $StorageAccountName `
    --name $ReleaseContainerName `
    --auth-mode login
Write-Host "Storage container $ReleaseContainerName created successfully" -ForegroundColor Green

# Upload function app release to blob storage
Write-Host "Uploading release in to storage account container $ReleaseContainerName..."
$BlobFileName = "GVG-$DeployTimestamp-$(New-Guid).zip"
az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $ReleaseContainerName `
    --file "./app.zip" `
    --name $BlobFileName `
    --timeout 2000 `
    --auth-mode login
Write-Host "Uploaded release to $ReleaseContainerName successfully" -ForegroundColor Green

# Set function app release blob in function app
Write-Host "Set function app to use latest release..."
az webapp config appsettings set `
    --name "$($AzureResourcePrefix.ToLower())-func" `
    --resource-group $ResourceGroupName `
    --settings WEBSITE_RUN_FROM_PACKAGE="https://$StorageAccountName.blob.core.windows.net/$ReleaseContainerName/$BlobFileName"
Write-Host "Function app set to use latest release successfully" -ForegroundColor Green

if (!$?) { 
    Write-Error "An error occured during the app deployment"
    exit 1
}
Write-Host "Deployed function app successfully" -ForegroundColor Green

Write-Host "DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green