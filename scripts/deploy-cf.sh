#!/bin/bash

# Simplified CloudFormation Deployment Script for Portfolio Contact Form

set -e

# Configuration
STACK_NAME="portfolio-contact-stack"
REGION="ap-southeast-1"
FROM_EMAIL="aannwaran@gmail.com"
TO_EMAIL="aannwaran@gmail.com"

echo "🚀 Deploying CloudFormation stack: $STACK_NAME"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in to AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Not logged in to AWS. Please run 'aws configure' first."
    exit 1
fi

# Create CloudFormation template as a temporary file
TEMPLATE_FILE="/tmp/portfolio-contact-template.yaml"
cat > "$TEMPLATE_FILE" << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Portfolio Contact Form Lambda with API Gateway'

Parameters:
  FromEmail:
    Type: String
    Description: 'Verified SES email address to send from'
    Default: 'aannwaran@gmail.com'
  ToEmail:
    Type: String
    Description: 'Email address to receive notifications'
    Default: 'aannwaran@gmail.com'

Resources:
  LambdaExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: portfolio-contact-lambda-role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
        - arn:aws:iam::aws:policy/AmazonSESFullAccess

  ContactHandlerFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: portfolio-contact-handler
      Runtime: nodejs20.x
      Handler: index.handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Environment:
        Variables:
          AWS_REGION: !Ref AWS::Region
          FROM_EMAIL: !Ref FromEmail
          TO_EMAIL: !Ref ToEmail
      Code:
        ZipFile: |
          const { SESClient, SendEmailCommand } = require("@aws-sdk/client-ses");
          
          const sesClient = new SESClient({
            region: process.env.AWS_REGION || "ap-southeast-1",
          });
          
          exports.handler = async (event) => {
            const headers = {
              "Access-Control-Allow-Origin": "*",
              "Access-Control-Allow-Headers": "Content-Type",
              "Access-Control-Allow-Methods": "POST, OPTIONS",
              "Content-Type": "application/json",
            };
            
            if (event.httpMethod === "OPTIONS") {
              return {
                statusCode: 200,
                headers,
                body: "",
              };
            }
            
            try {
              if (event.httpMethod !== "POST") {
                return {
                  statusCode: 405,
                  headers,
                  body: JSON.stringify({
                    error: "Method not allowed",
                  }),
                };
              }
              
              if (!event.body) {
                return {
                  statusCode: 400,
                  headers,
                  body: JSON.stringify({
                    error: "Missing request body",
                  }),
                };
              }
              
              const { name, email, message } = JSON.parse(event.body);
              
              if (!name || !email || !message) {
                return {
                  statusCode: 400,
                  headers,
                  body: JSON.stringify({
                    error: "Missing required fields",
                  }),
                };
              }
              
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
                Source: process.env.FROM_EMAIL,
                Destination: {
                  ToAddresses: [process.env.TO_EMAIL],
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
                      Data: `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Contact Message</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa; }
    .container { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 25px; border-radius: 12px 12px 0 0; margin: -30px -30px 30px -30px; text-align: center; }
    .header h1 { margin: 0; font-size: 28px; font-weight: 600; }
    .header p { margin: 5px 0 0 0; opacity: 0.9; font-size: 16px; }
    .field { margin-bottom: 20px; padding: 15px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #667eea; }
    .field-label { font-weight: 600; color: #667eea; margin-bottom: 5px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
    .field-value { font-size: 16px; word-wrap: break-word; }
    .message-field { background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); border-left: 4px solid #764ba2; }
    .message-content { background: white; padding: 20px; border-radius: 6px; margin-top: 10px; font-style: italic; position: relative; }
    .message-content:before { content: '"'; font-size: 48px; color: #667eea; opacity: 0.3; position: absolute; top: 10px; left: 10px; font-family: Georgia, serif; }
    .message-content p { margin: 0; padding-left: 20px; position: relative; z-index: 1; }
    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e9ecef; text-align: center; color: #6c757d; font-size: 14px; }
    .timestamp { background: #e7f3ff; color: #0066cc; padding: 8px 15px; border-radius: 20px; display: inline-block; font-weight: 500; }
    .button { display: inline-block; padding: 12px 24px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; border-radius: 6px; font-weight: 600; margin-top: 20px; transition: transform 0.2s; }
    .button:hover { transform: translateY(-2px); }
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
          weekday: "long", year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit" 
        })}
      </div>
      <p style="margin-top: 15px;">This message was sent from your portfolio contact form</p>
    </div>
  </div>
</body>
</html>`,
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
                  details: error.message || "Unknown error",
                }),
              };
            }
          };
      Timeout: 30

  ContactApi:
    Type: AWS::ApiGatewayV2::Api
    Properties:
      Name: portfolio-contact-api
      ProtocolType: HTTP
      CorsConfiguration:
        AllowOrigins: ["*"]
        AllowHeaders: ["*"]
        AllowMethods: ["*"]
        MaxAge: 300

  ApiIntegration:
    Type: AWS::ApiGatewayV2::Integration
    Properties:
      ApiId: !Ref ContactApi
      IntegrationType: AWS_PROXY
      IntegrationUri: !Sub arn:aws:lambda:${AWS::Region}:${AWS::AccountId}:function:${ContactHandlerFunction}
      PayloadFormatVersion: 2.0

  ApiRoute:
    Type: AWS::ApiGatewayV2::Route
    Properties:
      ApiId: !Ref ContactApi
      RouteKey: POST /contact
      Target: !Sub integrations/${ApiIntegration}

  ApiDeployment:
    Type: AWS::ApiGatewayV2::Deployment
    DependsOn: ApiRoute
    Properties:
      ApiId: !Ref ContactApi

  ApiStage:
    Type: AWS::ApiGatewayV2::Stage
    Properties:
      ApiId: !Ref ContactApi
      StageName: prod
      DeploymentId: !Ref ApiDeployment

  LambdaApiPermission:
    Type: AWS::Lambda::Permission
    Properties:
      FunctionName: !Ref ContactHandlerFunction
      Action: lambda:InvokeFunction
      Principal: apigateway.amazonaws.com
      SourceArn: !Sub arn:aws:execute-api:${AWS::Region}:${AWS::AccountId}:${ContactApi}/*/POST/contact

Outputs:
  ApiEndpoint:
    Description: 'API Gateway endpoint URL'
    Value: !Sub https://${ContactApi}.execute-api.${AWS::Region}.amazonaws.com/prod/contact
    Export:
      Name: PortfolioContactApiEndpoint
EOF

echo "🔍 CloudFormation template created"

# Check if stack already exists
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "")

if [ -n "$STACK_STATUS" ]; then
    echo "🔄 Updating existing stack..."
    
    # Update existing stack
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters \
            ParameterKey=FromEmail,ParameterValue="$FROM_EMAIL" \
            ParameterKey=ToEmail,ParameterValue="$TO_EMAIL" \
        --region "$REGION" \
        --capabilities CAPABILITY_IAM > /dev/null
    
    echo "⏳ Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    echo "✅ Stack updated successfully"
else
    echo "🆕 Creating new stack..."
    
    # Create new stack
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body "file://$TEMPLATE_FILE" \
        --parameters \
            ParameterKey=FromEmail,ParameterValue="$FROM_EMAIL" \
            ParameterKey=ToEmail,ParameterValue="$TO_EMAIL" \
        --region "$REGION" \
        --capabilities CAPABILITY_IAM > /dev/null
    
    echo "⏳ Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    echo "✅ Stack created successfully"
fi

# Get the API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

# Clean up temporary template file
rm -f "$TEMPLATE_FILE"

echo ""
echo "🎉 Deployment complete!"
echo "📧 Email endpoint: $API_ENDPOINT"
echo ""
echo "📝 Next steps:"
echo "1. Update your Contact.tsx component:"
echo "   fetch('$API_ENDPOINT', { ... })"
echo ""
echo "2. Test the endpoint:"
echo "   curl -X POST '$API_ENDPOINT' \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"message\":\"Hello World\"}'"
echo ""
echo "🔧 Stack management:"
echo "   - View stack: aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION"
echo "   - Delete stack: aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION"
echo "   - Update stack: ./lambda/scripts/deploy-cf.sh (run again)"

# Update Contact.tsx automatically
CONTACT_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/components/sections/Contact.tsx"
if [ -f "$CONTACT_FILE" ]; then
    echo ""
    echo "🔄 Updating Contact.tsx with new API endpoint..."
    
    # Create a backup
    cp "$CONTACT_FILE" "$CONTACT_FILE.backup"
    
    # Replace the API URL
    sed -i.tmp "s|https://your-api-id.execute-api.ap-southeast-1.amazonaws.com/prod/contact|$API_ENDPOINT|g" "$CONTACT_FILE"
    rm -f "$CONTACT_FILE.tmp"
    
    echo "✅ Contact.tsx updated successfully"
    echo "💾 Backup saved as: $CONTACT_FILE.backup"
else
    echo "⚠️  Could not find Contact.tsx file. Please update it manually with:"
    echo "   fetch('$API_ENDPOINT', { ... })"
fi