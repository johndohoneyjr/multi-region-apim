# PowerShell script to configure APIM backends and import OpenAI API
# Run this after the main provision script completes
# This script configures the OpenAI backends in APIM and imports the OpenAI API specification

param(
    [string]$resourceGroup = "apim-poc-rg",
    [string]$apimEast = "apim-poc-apim-east", 
    [string]$apimWest = "apim-poc-apim-west",
    [string]$openaiEast = "apim-poc-openai-east",
    [string]$openaiWest = "apim-poc-openai-west"
)

Write-Host "Configuring APIM backends for OpenAI..." -ForegroundColor Green

# Get OpenAI endpoints
$openaiEastEndpoint = az cognitiveservices account show --name $openaiEast --resource-group $resourceGroup --query "properties.endpoint" -o tsv
$openaiWestEndpoint = az cognitiveservices account show --name $openaiWest --resource-group $resourceGroup --query "properties.endpoint" -o tsv

# Configure backends in East APIM
Write-Host "Configuring backends in East APIM..." -ForegroundColor Yellow
az apim backend create --service-name $apimEast --resource-group $resourceGroup --backend-id "openai-east" --url "$openaiEastEndpoint" --protocol "http"
az apim backend create --service-name $apimEast --resource-group $resourceGroup --backend-id "openai-west" --url "$openaiWestEndpoint" --protocol "http"

# Configure backends in West APIM  
Write-Host "Configuring backends in West APIM..." -ForegroundColor Yellow
az apim backend create --service-name $apimWest --resource-group $resourceGroup --backend-id "openai-east" --url "$openaiEastEndpoint" --protocol "http"
az apim backend create --service-name $apimWest --resource-group $resourceGroup --backend-id "openai-west" --url "$openaiWestEndpoint" --protocol "http"

Write-Host "Importing OpenAI API specification..." -ForegroundColor Green

# Import OpenAI API spec to both APIM instances
$openaiApiSpec = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-06-01/inference.json"

az apim api import --service-name $apimEast --resource-group $resourceGroup --api-id "openai-api" --path "/openai" --specification-url $openaiApiSpec --specification-format "OpenApi" --display-name "OpenAI API"

az apim api import --service-name $apimWest --resource-group $resourceGroup --api-id "openai-api" --path "/openai" --specification-format "OpenApi" --specification-url $openaiApiSpec --display-name "OpenAI API"

Write-Host "APIM backend configuration complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Apply the geo-loadbalance policy XML to the OpenAI API operations"
Write-Host "2. Update policy XML placeholders with actual endpoint URLs and Event Grid details"
Write-Host "3. Test the multi-region failover functionality"
