#!/bin/bash

# AWS Lambda Deployment Script
# This script deploys the contact email handler to AWS Lambda

set -e

# Configuration
FUNCTION_NAME="portfolio-contact-handler"
REGION="ap-southeast-1"
ROLE_NAME="portfolio-contact-lambda-role"
LAMBDA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_FILE="$LAMBDA_DIR/function.zip"
HANDLER_FILE="$LAMBDA_DIR/contact-email-handler.ts"

echo "🚀 Deploying Lambda function: $FUNCTION_NAME"

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

# Create IAM Role if it doesn't exist
echo "📋 Checking IAM Role..."
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "🔧 Creating IAM Role..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' > /dev/null

    # Attach AWS Lambda Basic Execution Role
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    # Attach SES Policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonSESFullAccess"

    echo "⏳ Waiting for role to be ready..."
    sleep 10

    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "✅ Role created: $ROLE_ARN"
else
    echo "✅ Role already exists: $ROLE_ARN"
fi

# Build the Lambda function
echo "🔨 Building Lambda function..."
cd "$LAMBDA_DIR"

# Check if TypeScript is available
if ! command -v npx &> /dev/null; then
    echo "❌ npx not found. Please install Node.js and npm."
    exit 1
fi

# Create package.json for Lambda
cat > package.json << 'EOF'
{
  "name": "portfolio-contact-lambda",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@aws-sdk/client-ses": "^3.0.0"
  },
  "devDependencies": {
    "@types/aws-lambda": "^8.10.0",
    "typescript": "^5.0.0",
    "esbuild": "^0.19.0"
  }
}
EOF

# Install dependencies
npm install > /dev/null 2>&1

# Create TypeScript config
cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist"
  }
}
EOF

# Build with esbuild
npx esbuild contact-email-handler.ts \
    --bundle \
    --platform=node \
    --target=node20 \
    --format=esm \
    --outfile=index.js \
    --external:@aws-sdk/* > /dev/null 2>&1

# Create zip file
zip -r "$ZIP_FILE" index.js package.json node_modules/ > /dev/null 2>&1

echo "📦 Lambda package created"

# Update or Create Lambda function
echo "🔍 Checking if Lambda function exists..."
FUNCTION_EXISTS=$(aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "")

if [ "$FUNCTION_EXISTS" == "$FUNCTION_NAME" ]; then
    echo "🔄 Updating existing Lambda function..."
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" \
        --region "$REGION" > /dev/null
else
    echo "🆕 Creating new Lambda function..."
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "nodejs20.x" \
        --role "$ROLE_ARN" \
        --handler "index.handler" \
        --zip-file "fileb://$ZIP_FILE" \
        --region "$REGION" \
        --environment Variables="{AWS_REGION=$REGION}" > /dev/null
fi

# Clean up
rm -f index.js package.json package-lock.json tsconfig.json
rm -rf node_modules/
rm -f "$ZIP_FILE"

echo "✅ Lambda function deployed successfully!"

# Set up API Gateway
echo "🌐 Setting up API Gateway..."
API_NAME="portfolio-contact-api"

# Check if API already exists
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$API_NAME'].ApiId" --output text 2>/dev/null | grep -v None || echo "")

if [ -z "$API_ID" ]; then
    echo "🆕 Creating new API Gateway..."
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --target "$FUNCTION_NAME" \
        --region "$REGION" \
        --query 'ApiId' \
        --output text)

    # Create default route
    aws apigatewayv2 create-route \
        --api-id "$API_ID" \
        --route-key "POST /contact" \
        --target "integrations/$FUNCTION_NAME" \
        --region "$REGION" > /dev/null

    # Create integration
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id "$API_ID" \
        --integration-type AWS_PROXY \
        --integration-uri "arn:aws:lambda:$REGION:$(aws sts get-caller-identity --query Account --output text):function:$FUNCTION_NAME" \
        --payload-format-version "2.0" \
        --query 'IntegrationId' \
        --output text)

    # Set up integration response
    aws apigatewayv2 create-integration-response \
        --api-id "$API_ID" \
        --integration-id "$INTEGRATION_ID" \
        --integration-response-key "200" \
        --region "$REGION" > /dev/null

    # Create route response
    aws apigatewayv2 create-route-response \
        --api-id "$API_ID" \
        --route-id $(aws apigatewayv2 get-routes --api-id "$API_ID" --query 'Items[0].RouteId' --output text) \
        --route-response-key "200" \
        --region "$REGION" > /dev/null

    # Set up CORS
    aws apigatewayv2 update-api \
        --api-id "$API_ID" \
        --cors-configuration AllowOrigins="*" AllowHeaders="*" AllowMethods="*" \
        --region "$REGION" > /dev/null

    # Deploy API
    aws apigatewayv2 create-deployment \
        --api-id "$API_ID" \
        --stage-name prod \
        --region "$REGION" > /dev/null

    # Grant API Gateway permission to invoke Lambda
    aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "apigateway-invoke" \
        --action "lambda:InvokeFunction" \
        --principal "apigateway.amazonaws.com" \
        --source-arn "arn:aws:execute-api:$REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/POST/contact" \
        --region "$REGION" > /dev/null

    API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod/contact"
    echo "✅ API Gateway created: $API_URL"
else
    echo "✅ API Gateway already exists"
    API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/prod/contact"
fi

echo ""
echo "🎉 Deployment complete!"
echo "📧 Email endpoint: $API_URL"
echo ""
echo "📝 Next steps:"
echo "1. Set your Lambda environment variables:"
echo "   aws lambda update-function-configuration --function-name $FUNCTION_NAME --environment Variables='{FROM_EMAIL=aannwaran@gmail.com,TO_EMAIL=aannwaran@gmail.com}' --region $REGION"
echo ""
echo "2. Update your Contact.tsx to use the new endpoint:"
echo "   fetch('$API_URL', { ... })"
echo ""
echo "3. Test the endpoint:"
echo "   curl -X POST $API_URL -H 'Content-Type: application/json' -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"message\":\"Hello World\"}'"