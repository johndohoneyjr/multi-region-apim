"""
Azure Function: Event Grid Trigger for Token Usage Processing
This function processes APIM API call disposition events from Event Grid
and stores them in Redis cache as JSON data.

Deploy this to the token processor Function App created by the provision script.
"""
import azure.functions as func
import json
import redis
import os
import logging

# Initialize Redis connection
redis_connection_string = os.environ["REDIS_CONNECTION_STRING"]
redis_client = redis.from_url(f"redis://{redis_connection_string}")

app = func.FunctionApp()

@app.function_name(name="EventGridTrigger")
@app.event_grid_trigger(arg_name="event")
def eventgrid_trigger(event: func.EventGridEvent):
    """
    Processes Event Grid events containing API call disposition data
    and stores them in Redis cache.
    """
    try:
        # Get event data
        event_data = event.get_json()
        
        # Extract token usage data
        user_id = event_data.get("userId", "unknown")
        api_id = event_data.get("apiId", "")
        tokens_used = int(event_data.get("tokensUsed", 0))
        username = event_data.get("username", "")
        company_name = event_data.get("companyName", "")
        billing_code = event_data.get("billingCode", "")
        
        # Create Redis key and data
        redis_key = f"token-usage:{user_id}:{api_id}"
        usage_data = {
            "userId": user_id,
            "apiId": api_id,
            "tokensUsed": tokens_used,
            "username": username,
            "companyName": company_name,
            "billingCode": billing_code,
            "timestamp": event.event_time.isoformat()
        }
        
        # Store in Redis
        redis_client.set(redis_key, json.dumps(usage_data))
        
        # Update running total for user
        total_key = f"token-total:{user_id}"
        redis_client.incr(total_key, tokens_used)
        
        logging.info(f"Processed token usage for user {user_id}: {tokens_used} tokens")
        
    except Exception as e:
        logging.error(f"Error processing event: {str(e)}")
        raise
