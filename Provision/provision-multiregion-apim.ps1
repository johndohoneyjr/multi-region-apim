# Multi-Region Azure APIM POC Provisioning Script
# This script provisions:
# - Resource group
# - Two APIM instances (East US, West US) with managed identities
# - Two Azure OpenAI (Foundry) instances with gpt-4o and text-embedding-ada-002 models
# - Two serverless Azure Functions (as API backends) - Linux/Python
# - Azure Function triggered by Event Grid for token usage processing
# - Storage accounts for Function Apps
# - Traffic Manager profile (Performance routing)
# - Event Grid topic with Event Grid subscription to Function
# - Redis cache
# - RBAC assignments for APIM managed identities to access OpenAI
# - Advanced APIM policies for geo-conditional access and load balancing with failover
#Provision/provision-multiregion-apim.ps1
# NOTE: APIM policy XMLs and Function code samples are provided separately.
#
# Prerequisites: Azure CLI, PowerShell 7+, Contributor rights

param(
    [string]$baseName = "pros-poc",
    [string]$locationEast = "eastus",
    [string]$locationWest = "westus"
)

# Function to echo commands before executing them
function Invoke-AzCommand {
    param(
        [string]$Command
    )
    Write-Host "Executing: $Command" -ForegroundColor Gray
    Invoke-Expression $Command
}

# Function to echo and execute commands that assign variables
function Invoke-AzCommandWithAssignment {
    param(
        [string]$VariableName,
        [string]$Command
    )
    Write-Host "Executing: `$$VariableName = $Command" -ForegroundColor Gray
    $result = Invoke-Expression $Command
    Set-Variable -Name $VariableName -Value $result -Scope Script
    return $result
}

$resourceGroup = "$baseName-rg"
$apimEast = "$baseName-apim-east"
$apimWest = "$baseName-apim-west"
$functionEast = "$baseName-func-east"
$functionWest = "$baseName-func-west"
$eventGridTopic = "$baseName-eg-topic"
$redisName = "$baseName-redis"
$trafficManager = "$baseName-tm"
$uniqueDns = "$baseName-tm-$((Get-Random -Maximum 9999))"
$storageEast = "$($baseName.Replace('-',''))steast$(Get-Random -Maximum 999)"
$storageWest = "$($baseName.Replace('-',''))stwest$(Get-Random -Maximum 999)"
$tokenProcessorFunction = "$baseName-token-processor"
$openaiEast = "$baseName-openai-east"
$openaiWest = "$baseName-openai-west"

Write-Host "Creating resource group..." -ForegroundColor Green
Invoke-AzCommand "az group create --name $resourceGroup --location $locationEast"

Write-Host "Creating Event Grid topic..." -ForegroundColor Green
Invoke-AzCommand "az eventgrid topic create --resource-group $resourceGroup --name $eventGridTopic --location $locationEast"

Write-Host "Creating storage accounts for Function Apps..." -ForegroundColor Green
Invoke-AzCommand "az storage account create --name $storageEast --resource-group $resourceGroup --location $locationEast --sku Standard_LRS --kind StorageV2"
Invoke-AzCommand "az storage account create --name $storageWest --resource-group $resourceGroup --location $locationWest --sku Standard_LRS --kind StorageV2"

Write-Host "Creating Azure OpenAI instances..." -ForegroundColor Green
Invoke-AzCommand "az cognitiveservices account create --name $openaiEast --resource-group $resourceGroup --location $locationEast --kind OpenAI --sku S0"
Invoke-AzCommand "az cognitiveservices account create --name $openaiWest --resource-group $resourceGroup --location $locationWest --kind OpenAI --sku S0"

Write-Host "Deploying OpenAI models..." -ForegroundColor Green
# Deploy GPT-4o in East region
Invoke-AzCommand "az cognitiveservices account deployment create --name $openaiEast --resource-group $resourceGroup --deployment-name 'gpt-4o' --model-name 'gpt-4o' --model-version '2024-08-06' --model-format OpenAI --sku-capacity 30 --sku-name 'Standard'"

# Deploy text-embedding-ada-002 in East region
Invoke-AzCommand "az cognitiveservices account deployment create --name $openaiEast --resource-group $resourceGroup --deployment-name 'text-embedding-ada-002' --model-name 'text-embedding-ada-002' --model-version '2' --model-format OpenAI --sku-capacity 30 --sku-name 'Standard'"

# Deploy GPT-4o in West region
Invoke-AzCommand "az cognitiveservices account deployment create --name $openaiWest --resource-group $resourceGroup --deployment-name 'gpt-4o' --model-name 'gpt-4o' --model-version '2024-08-06' --model-format OpenAI --sku-capacity 30 --sku-name 'Standard'"

# Deploy text-embedding-ada-002 in West region
Invoke-AzCommand "az cognitiveservices account deployment create --name $openaiWest --resource-group $resourceGroup --deployment-name 'text-embedding-ada-002' --model-name 'text-embedding-ada-002' --model-version '2' --model-format OpenAI --sku-capacity 30 --sku-name 'Standard'"

Write-Host "Creating serverless Function Apps (Linux/Python)..." -ForegroundColor Green
Invoke-AzCommand "az functionapp create --resource-group $resourceGroup --consumption-plan-location $locationEast --runtime python --runtime-version 3.9 --functions-version 4 --name $functionEast --storage-account $storageEast --os-type Linux"
Invoke-AzCommand "az functionapp create --resource-group $resourceGroup --consumption-plan-location $locationWest --runtime python --runtime-version 3.9 --functions-version 4 --name $functionWest --storage-account $storageWest --os-type Linux"

Write-Host "Creating Event Grid triggered Function for token processing..." -ForegroundColor Green
Invoke-AzCommand "az functionapp create --resource-group $resourceGroup --consumption-plan-location $locationEast --runtime python --runtime-version 3.9 --functions-version 4 --name $tokenProcessorFunction --storage-account $storageEast --os-type Linux"

Write-Host "Creating APIM instances with managed identities..." -ForegroundColor Green
Invoke-AzCommand "az apim create --name $apimEast --resource-group $resourceGroup --location $locationEast --publisher-email 'admin@contoso.com' --publisher-name 'Contoso' --sku-name Developer --sku-capacity 1 --enable-managed-identity"
Invoke-AzCommand "az apim create --name $apimWest --resource-group $resourceGroup --location $locationWest --publisher-email 'admin@contoso.com' --publisher-name 'Contoso' --sku-name Developer --sku-capacity 1 --enable-managed-identity"

Write-Host "Configuring RBAC for APIM managed identities..." -ForegroundColor Green
# Get APIM managed identity principal IDs
$apimEastPrincipalId = Invoke-AzCommandWithAssignment "apimEastPrincipalId" "az apim show --name $apimEast --resource-group $resourceGroup --query 'identity.principalId' -o tsv"
$apimWestPrincipalId = Invoke-AzCommandWithAssignment "apimWestPrincipalId" "az apim show --name $apimWest --resource-group $resourceGroup --query 'identity.principalId' -o tsv"

# Get OpenAI resource IDs
$openaiEastId = Invoke-AzCommandWithAssignment "openaiEastId" "az cognitiveservices account show --name $openaiEast --resource-group $resourceGroup --query 'id' -o tsv"
$openaiWestId = Invoke-AzCommandWithAssignment "openaiWestId" "az cognitiveservices account show --name $openaiWest --resource-group $resourceGroup --query 'id' -o tsv"

# Assign "Cognitive Services OpenAI Contributor" role to APIM managed identities
Invoke-AzCommand "az role assignment create --assignee $apimEastPrincipalId --role 'a001fd3d-188f-4b5d-821b-7da978bf7442' --scope $openaiEastId"
Invoke-AzCommand "az role assignment create --assignee $apimEastPrincipalId --role 'a001fd3d-188f-4b5d-821b-7da978bf7442' --scope $openaiWestId"
Invoke-AzCommand "az role assignment create --assignee $apimWestPrincipalId --role 'a001fd3d-188f-4b5d-821b-7da978bf7442' --scope $openaiEastId"
Invoke-AzCommand "az role assignment create --assignee $apimWestPrincipalId --role 'a001fd3d-188f-4b5d-821b-7da978bf7442' --scope $openaiWestId"

Write-Host "Creating Redis cache..." -ForegroundColor Green
Invoke-AzCommand "az redis create --name $redisName --resource-group $resourceGroup --location $locationEast --sku Standard --vm-size C1"

Write-Host "Creating Traffic Manager profile..." -ForegroundColor Green
Invoke-AzCommand "az network traffic-manager profile create --name $trafficManager --resource-group $resourceGroup --routing-method Performance --unique-dns-name $uniqueDns --ttl 30 --protocol HTTP --port 80 --path '/'"

$apimEastUrl = Invoke-AzCommandWithAssignment "apimEastUrl" "az apim show --name $apimEast --resource-group $resourceGroup --query 'gatewayUrl' -o tsv"
$apimWestUrl = Invoke-AzCommandWithAssignment "apimWestUrl" "az apim show --name $apimWest --resource-group $resourceGroup --query 'gatewayUrl' -o tsv"

Write-Host "Adding Traffic Manager endpoints..." -ForegroundColor Green
Invoke-AzCommand "az network traffic-manager endpoint create --name 'east-endpoint' --profile-name $trafficManager --resource-group $resourceGroup --type externalEndpoints --target $($apimEastUrl -replace 'https://', '') --endpoint-location $locationEast"
Invoke-AzCommand "az network traffic-manager endpoint create --name 'west-endpoint' --profile-name $trafficManager --resource-group $resourceGroup --type externalEndpoints --target $($apimWestUrl -replace 'https://', '') --endpoint-location $locationWest"

Write-Host "Configuring Function App settings with Redis connection..." -ForegroundColor Green
$redisConnectionString = "$(Invoke-AzCommandWithAssignment 'redisHost' "az redis show --name $redisName --resource-group $resourceGroup --query 'hostName' -o tsv"):6380,password=$(Invoke-AzCommandWithAssignment 'redisKey' "az redis list-keys --name $redisName --resource-group $resourceGroup --query 'primaryKey' -o tsv"),ssl=True,abortConnect=False"
Invoke-AzCommand "az functionapp config appsettings set --name $tokenProcessorFunction --resource-group $resourceGroup --settings 'REDIS_CONNECTION_STRING=$redisConnectionString'"

Write-Host "Creating Event Grid subscription to trigger token processor function..." -ForegroundColor Green
$functionResourceId = Invoke-AzCommandWithAssignment "functionResourceId" "az functionapp show --name $tokenProcessorFunction --resource-group $resourceGroup --query 'id' -o tsv"
Invoke-AzCommand "az eventgrid event-subscription create --name 'token-usage-subscription' --source-resource-id $(Invoke-AzCommandWithAssignment 'eventGridTopicId' "az eventgrid topic show --name $eventGridTopic --resource-group $resourceGroup --query 'id' -o tsv") --endpoint '$functionResourceId/functions/EventGridTrigger' --endpoint-type azurefunction"

Write-Host "Fetching Event Grid, Redis, and OpenAI connection info..." -ForegroundColor Green
$eventGridEndpoint = Invoke-AzCommandWithAssignment "eventGridEndpoint" "az eventgrid topic show --name $eventGridTopic --resource-group $resourceGroup --query 'endpoint' -o tsv"
$eventGridKey = Invoke-AzCommandWithAssignment "eventGridKey" "az eventgrid topic key list --name $eventGridTopic --resource-group $resourceGroup --query 'key1' -o tsv"
$redisHost = Invoke-AzCommandWithAssignment "redisHost" "az redis show --name $redisName --resource-group $resourceGroup --query 'hostName' -o tsv"
$redisKey = Invoke-AzCommandWithAssignment "redisKey" "az redis list-keys --name $redisName --resource-group $resourceGroup --query 'primaryKey' -o tsv"
$openaiEastEndpoint = Invoke-AzCommandWithAssignment "openaiEastEndpoint" "az cognitiveservices account show --name $openaiEast --resource-group $resourceGroup --query 'properties.endpoint' -o tsv"
$openaiWestEndpoint = Invoke-AzCommandWithAssignment "openaiWestEndpoint" "az cognitiveservices account show --name $openaiWest --resource-group $resourceGroup --query 'properties.endpoint' -o tsv"

Write-Host "\n--- Connection Info ---" -ForegroundColor Yellow
Write-Host "Event Grid Endpoint: $eventGridEndpoint"
Write-Host "Event Grid Key: $eventGridKey"
Write-Host "Redis Host: $redisHost"
Write-Host "Redis Key: $redisKey"
Write-Host "OpenAI East Endpoint: $openaiEastEndpoint"
Write-Host "OpenAI West Endpoint: $openaiWestEndpoint"
Write-Host "\nTraffic Manager URL: $(Invoke-AzCommandWithAssignment 'trafficManagerUrl' "az network traffic-manager profile show --name $trafficManager --resource-group $resourceGroup --query 'dnsConfig.fqdn' -o tsv")" -ForegroundColor Yellow

Write-Host "\n--- NEXT STEPS ---" -ForegroundColor Cyan
Write-Host "1. Deploy your backend code to the two Function Apps ($functionEast, $functionWest)."
Write-Host "2. Deploy the Event Grid triggered function code to $tokenProcessorFunction."
Write-Host "3. Import your OpenAI API(s) into both APIM instances and configure backends to use OpenAI endpoints."
Write-Host "4. Apply the provided APIM policy XMLs for:"
Write-Host "   - Geo-conditional access and load balancing with failover"
Write-Host "   - Inbound (strip query params, store for event)"
Write-Host "   - Outbound (send event to Event Grid, circuit breaker)"
Write-Host "5. Test the multi-region failover by simulating 429 rate limit responses."
Write-Host "6. Test the Event Grid subscription by sending events to the topic."
Write-Host "\nSee Post-Provision folder for APIM policy XMLs and Function code samples."
