import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

const secretsClient = new SecretsManagerClient({ region: "us-east-1" });

// Cache the API key across invocations
let cachedApiKey = null;

async function getApiKey() {
  if (cachedApiKey) return cachedApiKey;
  
  const secretArn = process.env.OPENROUTER_SECRET_ARN;
  const command = new GetSecretValueCommand({ SecretId: secretArn });
  const response = await secretsClient.send(command);
  
  const secret = JSON.parse(response.SecretString);
  cachedApiKey = secret.api_key || secret.apiKey || secret.key;
  return cachedApiKey;
}

// Helper to get HTTP method from either API Gateway or Function URL event
function getHttpMethod(event) {
  return event.httpMethod || event.requestContext?.http?.method || 'GET';
}

// Helper to get path from either API Gateway or Function URL event
function getPath(event) {
  return event.path || event.rawPath || event.requestContext?.http?.path || '/';
}

export const handler = async (event) => {
  console.log("Request received:", JSON.stringify({
    method: getHttpMethod(event),
    path: getPath(event),
    isApiGateway: !!event.httpMethod
  }));

  const method = getHttpMethod(event);
  const path = getPath(event);

  // Handle OPTIONS preflight for CORS
  if (method === "OPTIONS") {
    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "content-type, authorization, x-requested-with"
      },
      body: ""
    };
  }

  try {
    // Get API key from Secrets Manager
    const apiKey = await getApiKey();

    // Handle /v1/models endpoint
    if (path.endsWith("/v1/models") && method === "GET") {
      console.log("Fetching models list");
      const response = await fetch("https://openrouter.ai/api/v1/models", {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "HTTP-Referer": "https://aws-lambda-proxy",
          "X-Title": "AWS Lambda OpenRouter Proxy"
        }
      });

      const data = await response.json();
      console.log("Models fetched successfully, count:", data.data?.length);
      
      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify(data)
      };
    }

    // Handle /v1/chat/completions endpoint
    if (path.endsWith("/v1/chat/completions") && method === "POST") {
      const body = JSON.parse(event.body || "{}");
      console.log("Chat request:", JSON.stringify({
        model: body.model,
        stream: body.stream,
        messageCount: body.messages?.length
      }));

      const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://aws-lambda-proxy",
          "X-Title": "AWS Lambda OpenRouter Proxy"
        },
        body: JSON.stringify(body)
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.error("OpenRouter error:", response.status, errorText);
        return {
          statusCode: response.status,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          },
          body: errorText
        };
      }

      // For API Gateway, we can't stream, so we always return the full response
      const data = await response.json();
      
      return {
        statusCode: 200,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
        body: JSON.stringify(data)
      };
    }

    // Unknown endpoint
    console.log("Unknown endpoint:", path);
    return {
      statusCode: 404,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
      body: JSON.stringify({ error: "Not found", path: path })
    };

  } catch (error) {
    console.error("Handler error:", error);
    return {
      statusCode: 500,
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
      body: JSON.stringify({ 
        error: error.message,
        type: error.name
      })
    };
  }
};
