# Azure DevOps Pipelines - Shared Templates

This repository contains reusable Azure DevOps pipeline templates for Docker, security scanning, testing, and Kubernetes deployment.

## Structure

```
pipelines/
├── templates/
│   ├── docker/              # Docker-related templates
│   │   ├── build-docker.yml
│   │   ├── scan-trivy.yml
│   │   ├── sign-cosign.yml
│   │   ├── sbom-syft.yml
│   │   └── push-ecr.yml
│   ├── security/            # Security scanning templates
│   │   ├── owasp-dependency-check.yml
│   │   └── sonarqube-analysis.yml
│   ├── test/                # Testing templates
│   │   ├── unit-tests.yml
│   │   └── integration-tests.yml
│   └── k8s/                 # Kubernetes deployment
│       └── deploy-eks.yml
└── vars/                    # Variable templates
    └── common-vars.yml
```

## Templates

### Docker Templates

#### build-docker.yml
Builds Docker images with BuildKit and layer caching.

**Parameters:**
- `dockerfilePath`: Path to Dockerfile
- `buildContext`: Build context directory
- `imageName`: Name of the image
- `imageTag`: Image tag (default: Build.BuildNumber)
- `enableCache`: Enable layer caching (default: true)
- `buildArgs`: Build arguments (object)

#### scan-trivy.yml
Scans Docker images for vulnerabilities using Trivy.

**Parameters:**
- `imageName`: Image to scan
- `imageTag`: Image tag
- `severityThreshold`: Severity levels to check (default: CRITICAL,HIGH)
- `failOnVulnerabilities`: Fail pipeline on vulnerabilities (default: true)

#### sign-cosign.yml
Signs Docker images using Cosign with keyless OIDC or keypair method.

**Parameters:**
- `imageName`: Image to sign
- `imageTag`: Image tag
- `signingMethod`: 'keyless' or 'keypair' (default: keyless)
- `rekorUrl`: Rekor transparency log URL

**Features:**
- Keyless signing with Azure DevOps OIDC
- Automatic signature verification
- Integration with Kyverno policies

#### sbom-syft.yml
Generates Software Bill of Materials using Syft.

**Parameters:**
- `imageName`: Image to analyze
- `imageTag`: Image tag
- `outputFormats`: SBOM formats (default: spdx-json, cyclonedx-json)
- `attachToImage`: Attach SBOM to image (default: true)

#### push-ecr.yml
Pushes images to AWS ECR with immutable tags.

**Parameters:**
- `imageName`: Image to push
- `imageTag`: Primary tag
- `ecrRegistry`: ECR registry URL
- `pushLatest`: Also push 'latest' tag (default: true)
- `additionalTags`: Additional tags to apply

**Features:**
- Automatic repository creation
- Immutable tag enforcement
- Image manifest generation
- Multiple tag support

### Security Templates

#### owasp-dependency-check.yml
Runs OWASP dependency checks for backend (Python) and frontend (JavaScript).

**Backend Tools:**
- Bandit (code security)
- pip-audit (dependency vulnerabilities)
- Safety (dependency security)

**Frontend Tools:**
- npm audit
- retire.js

**Parameters:**
- `projectType`: 'backend' or 'frontend'
- `workingDirectory`: Project directory
- `failOnHigh`: Fail on high-severity issues (default: true)

#### sonarqube-analysis.yml
Performs code quality and security analysis with SonarQube.

**Parameters:**
- `projectKey`: SonarQube project key
- `projectName`: Project display name
- `projectType`: 'backend' or 'frontend'
- `coveragePath`: Path to coverage report
- `qualityGateWait`: Wait for quality gate (default: true)

### Test Templates

#### unit-tests.yml
Runs unit tests with coverage for Python (pytest) or JavaScript (Jest).

**Parameters:**
- `projectType`: 'backend' or 'frontend'
- `workingDirectory`: Project directory
- `coverageThreshold`: Minimum coverage percentage (default: 80)
- `testCommand`: Custom test command (optional)

**Features:**
- Dependency caching (pip/npm)
- Coverage reporting
- Test result publishing
- Parallel test execution

#### integration-tests.yml
Runs integration tests with service containers (PostgreSQL, Redis).

**Parameters:**
- `projectType`: 'backend' or 'frontend'
- `workingDirectory`: Project directory
- `testCommand`: Custom test command
- `postgresVersion`: PostgreSQL version (default: 14)
- `redisVersion`: Redis version (default: 7)

**Features:**
- Automatic service container setup
- Database migrations
- Cleanup after tests

### Kubernetes Template

#### deploy-eks.yml
Deploys applications to AWS EKS with health checks and rollback.

**Parameters:**
- `environment`: Environment name (dev/staging/prod)
- `namespace`: Kubernetes namespace
- `manifestsPath`: Path to K8s manifests
- `imageTag`: Image tag to deploy
- `clusterName`: EKS cluster name
- `healthCheckTimeout`: Health check timeout in seconds (default: 300)
- `enableRollback`: Auto-rollback on failure (default: true)

**Features:**
- AWS IAM authentication (no static credentials)
- Automatic namespace creation
- Variable substitution in manifests
- Deployment health checks
- Automatic rollback on failure

## Usage

### In Your Pipeline

```yaml
stages:
  - stage: BuildImage
    jobs:
      - job: Docker
        steps:
          # Build
          - template: ../pipelines/templates/docker/build-docker.yml
            parameters:
              dockerfilePath: './Dockerfile'
              buildContext: '.'
              imageName: 'my-app'
              imageTag: $(Build.BuildNumber)

          # Scan
          - template: ../pipelines/templates/docker/scan-trivy.yml
            parameters:
              imageName: 'my-app'
              imageTag: $(Build.BuildNumber)

          # Sign
          - template: ../pipelines/templates/docker/sign-cosign.yml
            parameters:
              imageName: 'my-app'
              imageTag: $(Build.BuildNumber)
              signingMethod: 'keyless'

          # Push
          - template: ../pipelines/templates/docker/push-ecr.yml
            parameters:
              imageName: 'my-app'
              imageTag: $(Build.BuildNumber)
```

## Prerequisites

### Azure DevOps Service Connections

1. **AWS-ECR-ServiceConnection**: For ECR authentication
2. **AWS-ServiceConnection**: For AWS CLI operations
3. **SonarQube-ServiceConnection**: For SonarQube integration

### Azure DevOps Variable Groups

Create a variable group with:
- `aws-account-id`: AWS Account ID
- `eks-cluster-name`: EKS cluster name
- `sonarqube-url`: SonarQube server URL

### Required Tools

Templates automatically install:
- Trivy
- Cosign
- Syft
- Bandit, pip-audit (backend)
- npm audit, retire.js (frontend)

## Best Practices

1. **Caching**: All templates use caching where applicable (pip, npm, Docker layers)
2. **Parallel Execution**: Security scans run in parallel
3. **Fail Fast**: Critical vulnerabilities block the pipeline
4. **Immutable Tags**: Images tagged with build number and commit SHA
5. **Keyless Signing**: No key management overhead with OIDC
6. **Health Checks**: Automated deployment verification
7. **Rollback**: Automatic on deployment failure

## Integration with Infrastructure

These templates are designed to work with:
- **Kyverno**: Image signature verification
- **Network Policies**: Deployed automatically
- **Security Contexts**: Images built with non-root users
- **Resource Limits**: Defined in K8s manifests

## Support

For issues or questions, refer to:
- [Azure Pipelines Documentation](https://docs.microsoft.com/en-us/azure/devops/pipelines/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/)
