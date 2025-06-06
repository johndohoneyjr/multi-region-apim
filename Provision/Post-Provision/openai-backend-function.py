"""
Enhanced Azure Function: OpenAI Backend with token tracking
This function acts as a backend for APIM and includes token usage tracking.
Deploy this to the east and west Function Apps.
"""
import azure.functions as func
import json
import logging
import os
from azure.identity import DefaultAzureCredential
from azure.cognitiveservices.language.textanalytics import TextAnalyticsClient

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="api/openai/chat/completions", auth_level=func.AuthLevel.FUNCTION, methods=["POST"])
def openai_chat_completions(req: func.HttpRequest) -> func.HttpResponse:
    """
    OpenAI Chat Completions API proxy with token tracking
    Routes to the appropriate OpenAI deployment based on region.
    """
    try:
        # Get request data
        req_body = req.get_json() if req.get_body() else {}
        messages = req_body.get('messages', [])
        model = req_body.get('model', 'gpt-4o')
        max_tokens = req_body.get('max_tokens', 800)
        
        # Mock OpenAI response (replace with actual OpenAI SDK calls)
        response_content = "Mock response from OpenAI GPT-4o model"
        
        # Calculate token usage (simplified)
        prompt_tokens = sum(len(msg.get('content', '').split()) for msg in messages)
        completion_tokens = len(response_content.split())
        total_tokens = prompt_tokens + completion_tokens
        
        # Create OpenAI-compatible response
        response_data = {
            "id": f"chatcmpl-mock-{hash(str(messages)) % 1000000}",
            "object": "chat.completion",
            "created": 1677652288,
            "model": model,
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": response_content
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": prompt_tokens,
                "completion_tokens": completion_tokens,
                "total_tokens": total_tokens
            }
        }
        
        # Return response with token usage header for APIM policy
        response = func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "x-tokens-used": str(total_tokens),
                "x-model-used": model,
                "x-region": os.environ.get("WEBSITE_SITE_NAME", "unknown")
            }
        )
        
        logging.info(f"OpenAI Chat API called, model: {model}, tokens: {total_tokens}")
        return response
        
    except Exception as e:
        logging.error(f"Error in OpenAI Chat API: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": {"message": "Internal server error", "type": "server_error"}}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )

@app.route(route="api/openai/embeddings", auth_level=func.AuthLevel.FUNCTION, methods=["POST"])
def openai_embeddings(req: func.HttpRequest) -> func.HttpResponse:
    """
    OpenAI Embeddings API proxy with token tracking
    """
    try:
        # Get request data
        req_body = req.get_json() if req.get_body() else {}
        input_text = req_body.get('input', '')
        model = req_body.get('model', 'text-embedding-ada-002')
        
        # Mock embedding response (replace with actual OpenAI SDK calls)
        # In real implementation, call Azure OpenAI embeddings endpoint
        mock_embedding = [0.1] * 1536  # Ada-002 has 1536 dimensions
        
        # Calculate token usage
        tokens_used = len(input_text.split()) if isinstance(input_text, str) else sum(len(text.split()) for text in input_text)
        
        response_data = {
            "object": "list",
            "data": [{
                "object": "embedding",
                "index": 0,
                "embedding": mock_embedding
            }],
            "model": model,
            "usage": {
                "prompt_tokens": tokens_used,
                "total_tokens": tokens_used
            }
        }
        
        response = func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            headers={
                "Content-Type": "application/json",
                "x-tokens-used": str(tokens_used),
                "x-model-used": model,
                "x-region": os.environ.get("WEBSITE_SITE_NAME", "unknown")
            }
        )
        
        logging.info(f"OpenAI Embeddings API called, model: {model}, tokens: {tokens_used}")
        return response
        
    except Exception as e:
        logging.error(f"Error in OpenAI Embeddings API: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": {"message": "Internal server error", "type": "server_error"}}),
            status_code=500,
            headers={"Content-Type": "application/json"}
        )
