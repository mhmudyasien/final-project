# Slack Notifications for Azure DevOps Pipelines

Complete guide to integrating Slack notifications with Azure DevOps pipelines.

---

## Table of Contents

1. [Slack App Setup](#slack-app-setup)
2. [Azure DevOps Integration](#azure-devops-integration)
3. [Pipeline Notifications](#pipeline-notifications)
4. [Custom Notification Templates](#custom-notification-templates)
5. [Advanced Features](#advanced-features)

---

## Slack App Setup

### 1. Create Slack App

1. Go to https://api.slack.com/apps
2. Click **"Create New App"** → **"From scratch"**
3. **App Name**: `Azure DevOps Notifications`
4. **Workspace**: Select your workspace
5. Click **"Create App"**

### 2. Enable Incoming Webhooks

1. In your app settings, go to **"Incoming Webhooks"**
2. Toggle **"Activate Incoming Webhooks"** to **On**
3. Click **"Add New Webhook to Workspace"**
4. Select the channel (e.g., `#devops-alerts`)
5. Click **"Allow"**
6. **Copy the Webhook URL** (you'll need this later)

Example webhook URL:
```
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

### 3. Configure App Permissions (Optional)

For richer notifications:

1. Go to **"OAuth & Permissions"**
2. Add these scopes:
   - `chat:write`
   - `chat:write.public`
   - `files:write`
3. Click **"Install to Workspace"**
4. Copy the **OAuth Access Token**

---

## Azure DevOps Integration

### Method 1: Using Slack App from Marketplace (Easiest)

1. Go to Azure DevOps → **Organization Settings** → **Extensions**
2. Browse Marketplace → Search for **"Slack"**
3. Install **"Slack Notification for Azure Pipelines"**
4. Configure with your Slack webhook URL

### Method 2: Using Service Hooks (Recommended)

1. Go to **Project Settings** → **Service hooks**
2. Click **"+ Create subscription"**
3. Select **"Slack"**
4. Configure events:
   - Build completed
   - Build failed
   - Release deployment started
   - Release deployment completed
5. Enter your Slack webhook URL
6. Select channel and customize message

### Method 3: Custom Pipeline Task (Most Flexible)

Use inline PowerShell/Bash scripts in your pipeline.

---

## Pipeline Notifications

### 1. Add Slack Notification Task

Create a reusable template:

**File**: `pipelines/templates/notifications/slack-notify.yml`

```yaml
parameters:
  - name: webhookUrl
    type: string
  - name: message
    type: string
  - name: status
    type: string  # success, failure, warning
  - name: channel
    type: string
    default: '#devops-alerts'

steps:
  - task: Bash@3
    displayName: 'Send Slack Notification'
    condition: always()
    inputs:
      targetType: 'inline'
      script: |
        # Determine color based on status
        case "${{ parameters.status }}" in
          success)
            COLOR="good"
            EMOJI=":white_check_mark:"
            ;;
          failure)
            COLOR="danger"
            EMOJI=":x:"
            ;;
          warning)
            COLOR="warning"
            EMOJI=":warning:"
            ;;
          *)
            COLOR="#808080"
            EMOJI=":information_source:"
            ;;
        esac
        
        # Build JSON payload
        PAYLOAD=$(cat <<EOF
        {
          "channel": "${{ parameters.channel }}",
          "username": "Azure DevOps",
          "icon_emoji": ":azure:",
          "attachments": [
            {
              "color": "$COLOR",
              "title": "$EMOJI ${{ parameters.message }}",
              "fields": [
                {
                  "title": "Pipeline",
                  "value": "$(Build.DefinitionName)",
                  "short": true
                },
                {
                  "title": "Build Number",
                  "value": "$(Build.BuildNumber)",
                  "short": true
                },
                {
                  "title": "Branch",
                  "value": "$(Build.SourceBranchName)",
                  "short": true
                },
                {
                  "title": "Triggered By",
                  "value": "$(Build.RequestedFor)",
                  "short": true
                },
                {
                  "title": "Status",
                  "value": "${{ parameters.status }}",
                  "short": true
                },
                {
                  "title": "Duration",
                  "value": "$(Build.Duration)",
                  "short": true
                }
              ],
              "actions": [
                {
                  "type": "button",
                  "text": "View Build",
                  "url": "$(System.TeamFoundationCollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)"
                }
              ],
              "footer": "Azure DevOps",
              "footer_icon": "https://cdn.vsassets.io/content/icons/favicon.ico",
              "ts": $(date +%s)
            }
          ]
        }
        EOF
        )
        
        # Send to Slack
        curl -X POST \
          -H 'Content-type: application/json' \
          --data "$PAYLOAD" \
          ${{ parameters.webhookUrl }}
```

### 2. Use in Backend Pipeline

Update `backend-repo/azure-pipelines.yml`:

```yaml
variables:
  - group: common-variables
  - name: slackWebhook
    value: $(slack-webhook-url)  # From variable group

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          # ... existing steps ...
          
          # Notify on success
          - template: ../pipelines/templates/notifications/slack-notify.yml
            parameters:
              webhookUrl: $(slackWebhook)
              message: 'Backend build completed successfully'
              status: 'success'
              channel: '#backend-builds'
            condition: succeeded()
          
          # Notify on failure
          - template: ../pipelines/templates/notifications/slack-notify.yml
            parameters:
              webhookUrl: $(slackWebhook)
              message: 'Backend build failed'
              status: 'failure'
              channel: '#backend-builds'
            condition: failed()

  - stage: DeployProd
    jobs:
      - deployment: DeployToProd
        environment: 'production'
        strategy:
          runOnce:
            deploy:
              steps:
                # ... deployment steps ...
                
                # Notify deployment success
                - template: ../pipelines/templates/notifications/slack-notify.yml
                  parameters:
                    webhookUrl: $(slackWebhook)
                    message: 'Production deployment completed :rocket:'
                    status: 'success'
                    channel: '#production-deploys'
                  condition: succeeded()
```

### 3. Store Webhook URL Securely

**In Azure DevOps:**

1. Go to **Pipelines** → **Library**
2. Open `common-variables` variable group
3. Add variable:
   - **Name**: `slack-webhook-url`
   - **Value**: Your Slack webhook URL
   - **Secret**: ✅ **Check this box**
4. Save

---

## Custom Notification Templates

### 1. Rich Notification with Test Results

```yaml
- task: Bash@3
  displayName: 'Send Test Results to Slack'
  condition: always()
  inputs:
    targetType: 'inline'
    script: |
      # Get test results
      TOTAL_TESTS=$(cat $(Build.ArtifactStagingDirectory)/test-results/test-results.xml | grep -oP 'tests="\K[0-9]+' || echo "0")
      FAILED_TESTS=$(cat $(Build.ArtifactStagingDirectory)/test-results/test-results.xml | grep -oP 'failures="\K[0-9]+' || echo "0")
      PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
      
      # Determine status
      if [ "$FAILED_TESTS" -gt 0 ]; then
        COLOR="danger"
        STATUS="FAILED"
      else
        COLOR="good"
        STATUS="PASSED"
      fi
      
      PAYLOAD=$(cat <<EOF
      {
        "attachments": [
          {
            "color": "$COLOR",
            "title": "Test Results: $STATUS",
            "fields": [
              {"title": "Total Tests", "value": "$TOTAL_TESTS", "short": true},
              {"title": "Passed", "value": "$PASSED_TESTS", "short": true},
              {"title": "Failed", "value": "$FAILED_TESTS", "short": true},
              {"title": "Coverage", "value": "$(UnitTests.CodeCoverage)%", "short": true}
            ]
          }
        ]
      }
      EOF
      )
      
      curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $(slackWebhook)
```

### 2. Security Scan Notification

```yaml
- task: Bash@3
  displayName: 'Send Security Scan Results'
  condition: always()
  inputs:
    targetType: 'inline'
    script: |
      VULN_COUNT=$(TrivyScan.VulnerabilityCount)
      
      if [ "$VULN_COUNT" -gt 0 ]; then
        COLOR="danger"
        MESSAGE=":warning: Found $VULN_COUNT critical/high vulnerabilities"
      else
        COLOR="good"
        MESSAGE=":shield: No critical vulnerabilities found"
      fi
      
      PAYLOAD=$(cat <<EOF
      {
        "attachments": [
          {
            "color": "$COLOR",
            "title": "Security Scan Results",
            "text": "$MESSAGE",
            "fields": [
              {"title": "Image", "value": "$(imageName):$(imageTag)", "short": false},
              {"title": "Vulnerabilities", "value": "$VULN_COUNT", "short": true}
            ],
            "actions": [
              {
                "type": "button",
                "text": "View Report",
                "url": "$(System.TeamFoundationCollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)&view=artifacts"
              }
            ]
          }
        ]
      }
      EOF
      )
      
      curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $(slackWebhook)
```

### 3. Deployment Approval Request

```yaml
- task: Bash@3
  displayName: 'Request Deployment Approval'
  inputs:
    targetType: 'inline'
    script: |
      PAYLOAD=$(cat <<EOF
      {
        "attachments": [
          {
            "color": "warning",
            "title": ":rocket: Production Deployment Approval Required",
            "text": "A new deployment to production is waiting for approval",
            "fields": [
              {"title": "Application", "value": "Backend API", "short": true},
              {"title": "Version", "value": "$(Build.BuildNumber)", "short": true},
              {"title": "Requested By", "value": "$(Build.RequestedFor)", "short": true},
              {"title": "Branch", "value": "$(Build.SourceBranchName)", "short": true}
            ],
            "actions": [
              {
                "type": "button",
                "text": "Review & Approve",
                "url": "$(System.TeamFoundationCollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)",
                "style": "primary"
              }
            ]
          }
        ]
      }
      EOF
      )
      
      curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $(slackWebhook)
```

---

## Advanced Features

### 1. Thread Notifications

Keep related notifications in a thread:

```bash
# First message - save thread_ts
RESPONSE=$(curl -X POST -H 'Content-type: application/json' --data "$PAYLOAD" $(slackWebhook))
THREAD_TS=$(echo $RESPONSE | jq -r '.ts')

# Reply in thread
REPLY_PAYLOAD=$(cat <<EOF
{
  "thread_ts": "$THREAD_TS",
  "text": "Deployment completed successfully"
}
EOF
)
curl -X POST -H 'Content-type: application/json' --data "$REPLY_PAYLOAD" $(slackWebhook)
```

### 2. Mention Users/Groups

```json
{
  "text": "<!channel> Production deployment failed!",
  "attachments": [...]
}
```

Options:
- `<!channel>` - Notify all channel members
- `<!here>` - Notify active channel members
- `<@U12345678>` - Mention specific user (use Slack user ID)
- `<!subteam^S12345678>` - Mention user group

### 3. Interactive Buttons

```json
{
  "attachments": [
    {
      "callback_id": "deployment_approval",
      "actions": [
        {
          "name": "approve",
          "text": "Approve",
          "type": "button",
          "value": "approve",
          "style": "primary"
        },
        {
          "name": "reject",
          "text": "Reject",
          "type": "button",
          "value": "reject",
          "style": "danger"
        }
      ]
    }
  ]
}
```

### 4. File Uploads

Upload test reports or logs:

```bash
curl -F file=@test-report.html \
  -F "initial_comment=Test Report" \
  -F channels=#devops-alerts \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  https://slack.com/api/files.upload
```

---

## Notification Strategy

### Recommended Channels

| Channel | Purpose | Notifications |
|---------|---------|---------------|
| `#devops-alerts` | General alerts | Build failures, deployment issues |
| `#backend-builds` | Backend CI | Build status, test results |
| `#frontend-builds` | Frontend CI | Build status, test results |
| `#production-deploys` | Production | Deployment approvals, completions |
| `#security-alerts` | Security | Vulnerability scans, policy violations |

### Notification Levels

**Critical (Always notify):**
- Production deployment failures
- Security vulnerabilities (CRITICAL/HIGH)
- Infrastructure failures

**Important (Notify during business hours):**
- Staging deployment failures
- Test failures on main branch
- Quality gate failures

**Informational (Optional):**
- Successful builds
- Dev deployments
- Code coverage reports

---

## Example: Complete Pipeline with Notifications

```yaml
trigger:
  branches:
    include:
      - main

variables:
  - group: common-variables

stages:
  - stage: Build
    jobs:
      - job: BuildAndTest
        steps:
          - template: ../pipelines/templates/test/unit-tests.yml
          - template: ../pipelines/templates/docker/build-docker.yml
          - template: ../pipelines/templates/docker/scan-trivy.yml
          
          # Notify on completion
          - template: ../pipelines/templates/notifications/slack-notify.yml
            parameters:
              webhookUrl: $(slack-webhook-url)
              message: 'Build completed'
              status: 'success'
            condition: succeeded()
          
          - template: ../pipelines/templates/notifications/slack-notify.yml
            parameters:
              webhookUrl: $(slack-webhook-url)
              message: 'Build failed - check logs'
              status: 'failure'
            condition: failed()

  - stage: DeployProd
    dependsOn: Build
    jobs:
      - deployment: DeployToProd
        environment: 'production'
        strategy:
          runOnce:
            preDeploy:
              steps:
                # Request approval notification
                - template: ../pipelines/templates/notifications/slack-notify.yml
                  parameters:
                    webhookUrl: $(slack-webhook-url)
                    message: 'Production deployment approval required'
                    status: 'warning'
                    channel: '#production-deploys'
            
            deploy:
              steps:
                - template: ../pipelines/templates/k8s/deploy-eks.yml
            
            on:
              success:
                steps:
                  - template: ../pipelines/templates/notifications/slack-notify.yml
                    parameters:
                      webhookUrl: $(slack-webhook-url)
                      message: 'Production deployment successful :rocket:'
                      status: 'success'
                      channel: '#production-deploys'
              
              failure:
                steps:
                  - template: ../pipelines/templates/notifications/slack-notify.yml
                    parameters:
                      webhookUrl: $(slack-webhook-url)
                      message: '<!channel> Production deployment FAILED!'
                      status: 'failure'
                      channel: '#production-deploys'
```

---

## Troubleshooting

### Webhook Not Working

1. **Verify webhook URL** is correct
2. **Check channel permissions** - webhook must have access
3. **Test webhook** manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Test message"}' \
     YOUR_WEBHOOK_URL
   ```

### Messages Not Appearing

1. **Check Slack app permissions**
2. **Verify channel name** (include `#`)
3. **Check rate limits** (1 message per second)

### Variable Not Found

1. **Ensure variable group is linked** to pipeline
2. **Check variable name** matches exactly
3. **Verify secret variables** are properly configured

---

## Best Practices

1. ✅ **Use variable groups** for webhook URLs
2. ✅ **Mark webhooks as secret** variables
3. ✅ **Create separate channels** for different environments
4. ✅ **Use color coding** for status (green/red/yellow)
5. ✅ **Include action buttons** for quick access
6. ✅ **Avoid notification spam** - only critical events
7. ✅ **Use threads** for related notifications
8. ✅ **Test notifications** in dev channel first

---

## Next Steps

1. Create Slack channels for different notification types
2. Set up webhook URLs and store in variable groups
3. Add notification templates to your pipelines
4. Configure CloudWatch → SNS → Slack integration (see CloudWatch guide)
5. Create runbooks for common alerts
