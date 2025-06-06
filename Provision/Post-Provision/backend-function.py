"""
Sample Azure Function: HTTP Trigger Backend for APIM
This is a sample backend function that APIM can call.
Deploy this to the east and west Function Apps.
"""
import azure.functions as func
import json
import logging

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="api/llm", auth_level=func.AuthLevel.FUNCTION)
def llm_api(req: func.HttpRequest) -> func.HttpResponse:
    """
    Sample LLM API endpoint that returns mock response
    and includes token usage in response headers.
    """
    try:
        # Get request data
        req_body = req.get_json() if req.get_body() else {}
        prompt = req_body.get('prompt', 'Hello, world!')
        
        # Mock LLM processing
        response_text = f"Mock LLM response to: {prompt}"
        tokens_used = len(prompt.split()) + len(response_text.split())
        
        # Create response
        response_data = {
            "response": response_text,
            "model": "mock-llm-v1",
            "tokens": tokens_used
        }
        
        # Return response with token usage header
        response = func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "x-tokens-used": str(tokens_used)
            }
        )
        
        logging.info(f"LLM API called, used {tokens_used} tokens")
        return response
        
    except Exception as e:
        logging.error(f"Error in LLM API: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": "Internal server error"}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
