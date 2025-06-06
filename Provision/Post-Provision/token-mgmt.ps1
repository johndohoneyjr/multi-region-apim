# After APIM creation, add the token usage policy
Write-Host "Configuring APIM token usage policy..." -ForegroundColor Green

# Create named values for Event Grid
az apim nv create `
    --service-name $apimNameEast `
    --resource-group $resourceGroup `
    --named-value-id "EVENT_GRID_ENDPOINT" `
    --display-name "EVENT_GRID_ENDPOINT" `
    --value $eventGridEndpoint

az apim nv create `
    --service-name $apimNameEast `
    --resource-group $resourceGroup `
    --named-value-id "EVENT_GRID_KEY" `
    --display-name "EVENT_GRID_KEY" `
    --value $eventGridKey `
    --secret true

az apim nv create `
    --service-name $apimNameEast `
    --resource-group $resourceGroup `
    --named-value-id "APIM_REGION" `
    --display-name "APIM_REGION" `
    --value $locationEast

# Apply the policy to all APIs (you can also apply to specific APIs)
az apim policy apply `
    --service-name $apimNameEast `
    --resource-group $resourceGroup `
    --policy-format "xml" `
    --policy-content (Get-Content "token-usage-policy.xml" -Raw)

# Create Event Grid subscription for the Function App
Write-Host "Creating Event Grid subscription for Function App..." -ForegroundColor Green
$functionEndpoint = "https://$functionAppName.azurewebsites.net/runtime/webhooks/eventgrid?functionName=token_usage_processor"

az eventgrid event-subscription create `
    --source-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$resourceGroup/providers/Microsoft.EventGrid/topics/$eventGridTopicName" `
    --name "token-usage-subscription" `
    --endpoint $functionEndpoint `
    --endpoint-type webhook `
    --included-event-types "TokenUsage.Recorded"