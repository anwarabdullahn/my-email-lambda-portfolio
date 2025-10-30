import { SESClient, SendEmailCommand } from "@aws-sdk/client-ses";

interface ContactFormData {
  name: string;
  email: string;
  message: string;
}

interface APIGatewayProxyEvent {
  body: string | null;
  headers: Record<string, string>;
  httpMethod?: string; // v1
  requestContext: {
    requestId: string;
    stage?: string;
    http?: {
      method: string; // v2
      path: string;
    };
  };
}

interface APIGatewayProxyResult {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

const sesClient = new SESClient({
  region: process.env.AWS_REGION || "ap-southeast-1",
});

export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  // Enable CORS for all origins
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };

  // Get HTTP method (supports both v1 and v2 format)
  const httpMethod = event.httpMethod || event.requestContext?.http?.method;

  // Handle preflight OPTIONS request
  if (httpMethod === "OPTIONS") {
    return {
      statusCode: 200,
      headers,
      body: "",
    };
  }

  try {
    // Validate request method
    if (httpMethod !== "POST") {
      return {
        statusCode: 405,
        headers,
        body: JSON.stringify({
          error: "Method not allowed",
        }),
      };
    }

    // Parse and validate request body
    if (!event.body) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: "Missing request body",
        }),
      };
    }

    const { name, email, message }: ContactFormData = JSON.parse(event.body);

    // Validate input
    if (!name || !email || !message) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: "Missing required fields",
        }),
      };
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          error: "Invalid email address",
        }),
      };
    }

    const emailCommand = new SendEmailCommand({
      Source: process.env.FROM_EMAIL || "aannwaran@gmail.com",
      Destination: {
        ToAddresses: [process.env.TO_EMAIL || "aannwaran@gmail.com"],
      },
      Message: {
        Subject: {
          Data: `New Contact Message from ${name}`,
        },
        Body: {
          Text: {
            Data: `You have received a new message from your portfolio contact form:

Name: ${name}
Email: ${email}
Message: ${message}

---
Sent on: ${new Date().toLocaleString()}`,
          },
          Html: {
            Data: `
              <!DOCTYPE html>
              <html>
              <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>New Contact Message</title>
                <style>
                  body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 20px;
                    background-color: #f8f9fa;
                  }
                  .container {
                    background: white;
                    padding: 30px;
                    border-radius: 12px;
                    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                  }
                  .header {
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    padding: 25px;
                    border-radius: 12px 12px 0 0;
                    margin: -30px -30px 30px -30px;
                    text-align: center;
                  }
                  .header h1 {
                    margin: 0;
                    font-size: 28px;
                    font-weight: 600;
                  }
                  .header p {
                    margin: 5px 0 0 0;
                    opacity: 0.9;
                    font-size: 16px;
                  }
                  .field {
                    margin-bottom: 20px;
                    padding: 15px;
                    background: #f8f9fa;
                    border-radius: 8px;
                    border-left: 4px solid #667eea;
                  }
                  .field-label {
                    font-weight: 600;
                    color: #667eea;
                    margin-bottom: 5px;
                    font-size: 14px;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                  }
                  .field-value {
                    font-size: 16px;
                    word-wrap: break-word;
                  }
                  .message-field {
                    background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
                    border-left: 4px solid #764ba2;
                  }
                  .message-content {
                    background: white;
                    padding: 20px;
                    border-radius: 6px;
                    margin-top: 10px;
                    font-style: italic;
                    position: relative;
                  }
                  .message-content:before {
                    content: '"';
                    font-size: 48px;
                    color: #667eea;
                    opacity: 0.3;
                    position: absolute;
                    top: 10px;
                    left: 10px;
                    font-family: Georgia, serif;
                  }
                  .message-content p {
                    margin: 0;
                    padding-left: 20px;
                    position: relative;
                    z-index: 1;
                  }
                  .footer {
                    margin-top: 30px;
                    padding-top: 20px;
                    border-top: 1px solid #e9ecef;
                    text-align: center;
                    color: #6c757d;
                    font-size: 14px;
                  }
                  .timestamp {
                    background: #e7f3ff;
                    color: #0066cc;
                    padding: 8px 15px;
                    border-radius: 20px;
                    display: inline-block;
                    font-weight: 500;
                  }
                  .button {
                    display: inline-block;
                    padding: 12px 24px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    text-decoration: none;
                    border-radius: 6px;
                    font-weight: 600;
                    margin-top: 20px;
                    transition: transform 0.2s;
                  }
                  .button:hover {
                    transform: translateY(-2px);
                  }
                </style>
              </head>
              <body>
                <div class="container">
                  <div class="header">
                    <h1>📬 New Contact Message</h1>
                    <p>Someone wants to connect with you!</p>
                  </div>
                  
                  <div class="field">
                    <div class="field-label">From</div>
                    <div class="field-value">
                      <strong>${name}</strong><br>
                      <a href="mailto:${email}" style="color: #667eea;">${email}</a>
                    </div>
                  </div>
                  
                  <div class="field message-field">
                    <div class="field-label">Message</div>
                    <div class="message-content">
                      <p>${message.replace(/\n/g, "<br>")}</p>
                    </div>
                  </div>
                  
                  <div style="text-align: center;">
                    <a href="mailto:${email}" class="button">📧 Reply to ${name}</a>
                  </div>
                  
                  <div class="footer">
                    <div class="timestamp">
                      🕒 Sent on ${new Date().toLocaleString("en-US", { 
                        weekday: "long", 
                        year: "numeric", 
                        month: "long", 
                        day: "numeric", 
                        hour: "2-digit", 
                        minute: "2-digit" 
                      })}
                    </div>
                    <p style="margin-top: 15px;">
                      This message was sent from your portfolio contact form
                    </p>
                  </div>
                </div>
              </body>
              </html>
            `,
          },
        },
      },
    });

    await sesClient.send(emailCommand);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        success: true,
        message: "Email sent successfully",
      }),
    };
  } catch (error) {
    console.error("Error sending email:", error);

    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({
        error: "Failed to send email. Please try again later.",
        details: error instanceof Error ? error.message : "Unknown error",
      }),
    };
  }
};