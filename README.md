# AWS Lambda Contact Form Handler

This directory contains the AWS Lambda function that handles email sending for your portfolio contact form.

## 🏗️ Architecture

```
GitHub Pages (Static Site) → API Gateway → AWS Lambda → AWS SES → Your Email
```

- **GitHub Pages**: Serves your static portfolio site
- **API Gateway**: Provides HTTP endpoint for your Lambda
- **AWS Lambda**: Runs the email sending logic
- **AWS SES**: Sends the actual emails

## 📁 Files

- `contact-email-handler.ts` - Main Lambda function code (TypeScript)
- `scripts/deploy.sh` - Automated deployment script
- `package.json` - Node.js dependencies
- `tsconfig.json` - TypeScript configuration
- `README.md` - This file

## 🚀 Current Deployment

**Lambda Function:**
- **Name**: `portfolio-contact-handler`
- **Region**: `ap-southeast-1`
- **Runtime**: `nodejs18.x`
- **Handler**: `index.handler`

**API Gateway:**
- **Name**: `portfolio-contact-api`
- **API ID**: `vlqjs0wen0`
- **Endpoint**: `https://vlqjs0wen0.execute-api.ap-southeast-1.amazonaws.com/prod/contact`
- **Method**: `POST /contact`

**SES Configuration:**
- **FROM**: `aannwaran@gmail.com` ✅ Verified
- **TO**: `aannwaran@gmail.com` ✅ Verified
- **Status**: Sandbox Mode (can only send to verified addresses)

## 🔄 Updating Lambda Function

When you make changes to `contact-email-handler.ts`, follow these steps:

### Option 1: Quick Update (Recommended)

```bash
# 1. Build the TypeScript code
npx esbuild lambda/contact-email-handler.ts \
  --bundle \
  --platform=node \
  --target=node18 \
  --format=esm \
  --outfile=lambda/index.js \
  '--external:@aws-sdk/*'

# 2. Create deployment package
zip -j lambda/function.zip lambda/index.js

# 3. Update Lambda function
aws lambda update-function-code \
  --function-name portfolio-contact-handler \
  --zip-file fileb://lambda/function.zip \
  --region ap-southeast-1

# 4. Clean up build artifacts
rm lambda/index.js lambda/function.zip

# 5. Verify deployment
aws lambda get-function \
  --function-name portfolio-contact-handler \
  --region ap-southeast-1 \
  --query 'Configuration.[FunctionName,LastModified,Runtime]'
```

### Option 2: Using Deployment Script

```bash
# Note: The deploy.sh script has a known issue with cleanup
# Use Option 1 for now until the script is fixed
bash lambda/scripts/deploy.sh
```

## 📋 Useful AWS Commands

### Lambda Management

```bash
# Get function info
aws lambda get-function \
  --function-name portfolio-contact-handler \
  --region ap-southeast-1

# Get function configuration
aws lambda get-function-configuration \
  --function-name portfolio-contact-handler \
  --region ap-southeast-1

# Update environment variables
aws lambda update-function-configuration \
  --function-name portfolio-contact-handler \
  --environment Variables='{FROM_EMAIL=aannwaran@gmail.com,TO_EMAIL=aannwaran@gmail.com,AWS_REGION=ap-southeast-1}' \
  --region ap-southeast-1

# View CloudWatch logs (last 10 minutes)
aws logs tail /aws/lambda/portfolio-contact-handler \
  --region ap-southeast-1 \
  --since 10m \
  --format short

# Follow logs in real-time
aws logs tail /aws/lambda/portfolio-contact-handler \
  --region ap-southeast-1 \
  --follow
```

### API Gateway Management

```bash
# List all APIs
aws apigatewayv2 get-apis \
  --region ap-southeast-1 \
  --query "Items[?Name=='portfolio-contact-api']"

# Get API details
aws apigatewayv2 get-api \
  --api-id vlqjs0wen0 \
  --region ap-southeast-1

# List routes
aws apigatewayv2 get-routes \
  --api-id vlqjs0wen0 \
  --region ap-southeast-1

# List stages
aws apigatewayv2 get-stages \
  --api-id vlqjs0wen0 \
  --region ap-southeast-1

# Get integration details
aws apigatewayv2 get-integrations \
  --api-id vlqjs0wen0 \
  --region ap-southeast-1

# Update CORS settings
aws apigatewayv2 update-api \
  --api-id vlqjs0wen0 \
  --cors-configuration 'AllowOrigins=*,AllowHeaders=Content-Type,AllowMethods=POST,OPTIONS' \
  --region ap-southeast-1
```

### SES Management

```bash
# List verified email addresses
aws sesv2 list-email-identities \
  --region ap-southeast-1

# Check email verification status
aws sesv2 get-email-identity \
  --email-identity aannwaran@gmail.com \
  --region ap-southeast-1

# Check SES account status (sandbox vs production)
aws sesv2 get-account \
  --region ap-southeast-1

# Verify a new email address
aws sesv2 create-email-identity \
  --email-identity new-email@example.com \
  --region ap-southeast-1

# Request production access (after this, submit via AWS Console)
# Go to: https://console.aws.amazon.com/ses/home?region=ap-southeast-1#/account
```

### IAM Role Management

```bash
# Get role details
aws iam get-role \
  --role-name portfolio-contact-lambda-role

# List attached policies
aws iam list-attached-role-policies \
  --role-name portfolio-contact-lambda-role

# Check Lambda permissions for API Gateway
aws lambda get-policy \
  --function-name portfolio-contact-handler \
  --region ap-southeast-1
```

## 🧪 Testing

### Test the endpoint directly

```bash
# Basic test
curl -X POST https://vlqjs0wen0.execute-api.ap-southeast-1.amazonaws.com/prod/contact \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test User","email":"aannwaran@gmail.com","message":"Test message"}'

# Test with verbose output
curl -v -X POST https://vlqjs0wen0.execute-api.ap-southeast-1.amazonaws.com/prod/contact \
  -H 'Content-Type: application/json' \
  -d '{"name":"Test User","email":"aannwaran@gmail.com","message":"Test message"}'

# Test CORS (OPTIONS request)
curl -X OPTIONS https://vlqjs0wen0.execute-api.ap-southeast-1.amazonaws.com/prod/contact \
  -H 'Origin: https://example.com' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: Content-Type' \
  -v
```

### Expected Response

**Success:**
```json
{
  "success": true,
  "message": "Email sent successfully"
}
```

**Error:**
```json
{
  "error": "Failed to send email. Please try again later.",
  "details": "Error message here"
}
```

## 🔧 Environment Variables

Current configuration in Lambda:

| Variable | Value | Description |
|----------|-------|-------------|
| `AWS_REGION` | `ap-southeast-1` | AWS region for SES |
| `FROM_EMAIL` | `aannwaran@gmail.com` | Sender email (must be verified in SES) |
| `TO_EMAIL` | `aannwaran@gmail.com` | Recipient email (receives contact form submissions) |

## 🔒 Security

- ✅ No credentials exposed in client code
- ✅ Lambda runs with least-privilege IAM role
- ✅ CORS enabled for cross-origin requests
- ✅ Input validation (email regex, required fields)
- ✅ Error handling with generic error messages
- ✅ API Gateway throttling enabled

## ⚠️ SES Sandbox Mode

Your SES account is currently in **sandbox mode**, which means:

- ✅ Can send FROM verified email addresses
- ✅ Can send TO verified email addresses
- ❌ Cannot send to unverified email addresses
- ❌ Limited to 200 emails per day
- ❌ Maximum send rate of 1 email per second

**For Production:** Request production access to send emails to any address:

1. Go to [SES Console](https://console.aws.amazon.com/ses/home?region=ap-southeast-1#/account)
2. Click **"Request production access"**
3. Fill out the form with:
   - Use case: Transactional emails for portfolio contact form
   - Expected sending volume: ~100 emails/month
   - Bounce/complaint handling: Will monitor SES dashboard
4. Usually approved within 24 hours

## 💰 Cost Estimate

For a personal portfolio with ~50 contact form submissions per month:

| Service | Free Tier | Cost |
|---------|-----------|------|
| Lambda | 1M requests/month | $0.00 |
| API Gateway | 1M API calls/month | $0.00 |
| SES | 62,000 emails/month | $0.00 |
| CloudWatch Logs | 5GB ingestion | $0.00 |

**Total: $0.00/month** (well within free tier limits)

## 🐛 Troubleshooting

### Common Issues

**1. 500 Internal Server Error**
```bash
# Check CloudWatch logs
aws logs tail /aws/lambda/portfolio-contact-handler --region ap-southeast-1 --since 5m
```

**2. CORS Errors in Browser**
```bash
# Verify CORS is enabled on API Gateway
aws apigatewayv2 get-api --api-id vlqjs0wen0 --region ap-southeast-1 --query 'CorsConfiguration'
```

**3. Email Not Sending (SES Sandbox)**
- Ensure both FROM and TO emails are verified in SES
- Request production access for unrestricted sending

**4. "Cannot find module 'index'" Error**
- Lambda function code not properly deployed
- Follow "Option 1: Quick Update" steps above

**5. Timeout Errors**
```bash
# Increase Lambda timeout (default is 3 seconds)
aws lambda update-function-configuration \
  --function-name portfolio-contact-handler \
  --timeout 30 \
  --region ap-southeast-1
```

### Debug Checklist

- [ ] Check Lambda function exists and is updated
- [ ] Verify environment variables are set correctly
- [ ] Ensure SES emails are verified
- [ ] Confirm API Gateway route is connected to Lambda
- [ ] Check IAM role has SES permissions
- [ ] Review CloudWatch logs for errors
- [ ] Test endpoint with curl before testing in browser

## 🔄 Full Redeployment (If Needed)

If you need to completely redeploy from scratch:

```bash
# 1. Delete existing resources
aws lambda delete-function \
  --function-name portfolio-contact-handler \
  --region ap-southeast-1

aws apigatewayv2 delete-api \
  --api-id vlqjs0wen0 \
  --region ap-southeast-1

# 2. Run deployment script
bash lambda/scripts/deploy.sh

# 3. Update Contact.tsx with new API endpoint
```

## 📊 Monitoring

### CloudWatch Metrics

View Lambda metrics:
```bash
# Get invocation count (last hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=portfolio-contact-handler \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region ap-southeast-1

# Get error count
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=portfolio-contact-handler \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum \
  --region ap-southeast-1
```

## 📚 References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [API Gateway HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
- [AWS SES Developer Guide](https://docs.aws.amazon.com/ses/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [esbuild Documentation](https://esbuild.github.io/)

## 📝 Notes

- Lambda function uses ESM (ES Modules) format for better tree-shaking
- TypeScript is compiled to JavaScript using esbuild (fast, no dependencies)
- AWS SDK v3 is used (lighter, more modular than v2)
- API Gateway v2 (HTTP API) is cheaper and simpler than v1 (REST API)
- HTML email template included for better-looking notifications
