# Run Connect-AzureAd manually first

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resourceGroupName = "rg17"
$tenantId = [System.Environment]::GetEnvironmentVariable('ACC_TID')      
$adAppRepresentingApiName = "DemoOrgService-$resourceGroupName"
$apiResourceUri = "api://demo-orgservice-$resourceGroupName"

# Create an app representing our new API resource in App Service
$adAppRepresentingApi = New-AzureADApplication -DisplayName $adAppRepresentingApiName -IdentifierUris $apiResourceUri -Oauth2AllowImplicitFlow $false

# Clear out scopes created (stupidly) by New-AzureADApplication Cmdlet
# TODO Check this - might be failing role inclusion
# https://stackoverflow.com/a/62694506
#$Scopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]
#$Scope = $adAppRepresentingApi.Oauth2Permissions | Where-Object { $_.Value -eq "user_impersonation" }
#$Scope.IsEnabled = $false
#$Scopes.Add($Scope)
#Set-AzureADApplication -ObjectId $adAppRepresentingApi.ObjectID -Oauth2Permissions $Scopes
#$EmptyScopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]
#Set-AzureADApplication -ObjectId $adAppRepresentingApi.ObjectID -Oauth2Permissions $EmptyScopes

# Create app role that our API will require for authorization
$newAppRole = [Microsoft.Open.AzureAD.Model.AppRole]::new()
$newAppRole.DisplayName = "Get keys display name"
$newAppRole.Description = "Get keys description"
$newAppRole.Value = "Get.Keys"
$newAppRole.Id = [Guid]::NewGuid().ToString()
$newAppRole.IsEnabled = $true
$newAppRole.AllowedMemberTypes = @("User", "Application")

# and assign to App
Set-AzureADApplication -ObjectId $adAppRepresentingApi.ObjectId -AppRoles @($newAppRole)

# Create a service principal for the app, so it appears in Enterprise Apps etc
New-AzureADServicePrincipal -AppId $adAppRepresentingApi.AppId

Write-Output "ClientId is $($adAppRepresentingApi.AppId)"


# Create Resource Group
New-AzResourceGroup -Name $resourceGroupName -Location 'UKSouth'


# Create web app that will consume token
$appServicePlanName = "$resourceGroupName-ASP"
New-AzAppServicePlan -ResourceGroupName $resourceGroupName -Location "UK South" -Tier Free -NumberofWorkers 1 -Linux -Name $appServicePlanName -WorkerSize Small

$appServiceAppName = "azureadprotectedapi-$resourceGroupName"
az webapp create --resource-group $resourceGroupName --name $appServiceAppName --plan $appServicePlanName --deployment-container-image-name potomato/azureadprotectedapi

$appServiceAppSettings = @{ AzureAd__Audience = $apiResourceUri; AzureAd__ClientId = $adAppRepresentingApi.AppId; AzureAd__TenantId = $tenantId }
Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $appServiceAppName -AppSettings $appServiceAppSettings

$apiHostname = (Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $appServiceAppName).EnabledHostNames | Select -First 1


# Build userdata to pass new URIs to VM
$userdataText = "API_DOMAIN=$apiHostname`nAPI_APP_URI=$apiResourceUri";
$userdataBytes = [System.Text.Encoding]::ASCII.GetBytes($userdataText);
$userData = [Convert]::ToBase64String($userdataBytes);

#Create VM
$vmName = "VM-$resourceGroupName"
$VMLocalAdminUser = "VmUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "GreatBooIsUp!1" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location 'UKSouth' `
	-Image 'Debian:debian-11:11:latest' `
	-Size Standard_B1s `
	-SystemAssignedIdentity `
	-Credential $Credential `
	-UserData $userData

# Run command to add packages
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunShellScript' -ScriptString 'sudo apt-get update && sudo apt-get install -y curl jq'

# 'curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text" | base64 --decode'

# Get service principal Id of VM System Assigned Identity
$vmIdentityPrincipalId = (Get-AzVm -ResourceGroupName $resourceGroupName -Name $vmName).Identity.PrincipalId

# Get service principal of AD app representing our API
$appServicePrincipalObjectId = (Get-AzureADServicePrincipal -Filter "DisplayName eq '$adAppRepresentingApiName'").ObjectId

# Assign our app's App Role to the VM system identity
New-AzureADServiceAppRoleAssignment `
    -ObjectId $vmIdentityPrincipalId `
    -Id $newAppRole.Id `
    -PrincipalId $vmIdentityPrincipalId `
    -ResourceId $appServicePrincipalObjectId


# Restart-AzVM -ResourceGroupName $resourceGroupName -Name $vmName

# Request and display a token on VM for our API
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -Name $vmName -CommandId 'RunShellScript' -ScriptString "curl ""http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$apiResourceUri"" -H Metadata:true -s | jq '.access_token'"

Get-AzureADServiceAppRoleAssignedTo -ObjectId $vmIdentityPrincipalId
