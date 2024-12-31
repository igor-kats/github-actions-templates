# github-actions-templates

# AWS ECR Docker Build and Push Script

This repository provides a Bash script to automate the process of building and pushing Docker images to an AWS Elastic Container Registry (ECR). The script is designed for use in CI/CD pipelines and supports tagging based on GitHub events.

---

## Features
- **Environment Variable Validation**: Ensures all required variables are set.
- **AWS CLI Installation**: Automatically installs AWS CLI if not found.
- **ECR Repository Validation**: Verifies that the specified ECR repository exists.
- **Docker Build and Push**: Builds Docker images using configurable Dockerfile paths and contexts, then pushes them to ECR.
- **Flexible Tagging**: Supports dynamic tagging based on GitHub branch or tag references.
- **Error Handling**: Provides detailed logs and strict error handling.

---

## Prerequisites

1. **AWS CLI**: The script requires AWS CLI to interact with ECR. If not installed, the script will attempt to install it.
2. **Docker**: Ensure Docker is installed and configured.
3. **GitHub Environment Variables**: The script relies on several GitHub Actions environment variables, including:
   - `GITHUB_SHA`: Commit SHA for tagging.
   - `GITHUB_REF_NAME`: The branch or tag name.
   - `GITHUB_REF_TYPE`: Indicates if the reference is a branch or a tag.
   - `GITHUB_OUTPUT`: Used to export outputs.
4. **AWS Permissions**: The AWS credentials used must have sufficient permissions to describe ECR repositories, log in to ECR, and push images.

---

## Configuration

The script uses a set of environment variables for configuration. Default values can be overridden by exporting the variables before running the script.

| Variable           | Description                                      | Default Value               |
|--------------------|--------------------------------------------------|-----------------------------|
| `REGION`           | AWS region for ECR.                             | `us-east-1`                |
| `TAG`              | Default Docker tag.                             | `pre-test`                 |
| `DOCKERFILE_PATH`  | Path to the Dockerfile.                         | `.`                         |
| `DOCKERFILE_CONTEXT` | Build context for Docker.                     | `.`                         |
| `ACCOUNT_ID`       | AWS account ID for ECR.                         | `<ACCOUNT_ID_WHERE_TO_BUILD_IMAGE>` |
| `SERVICE_NAME`     | Name of the service (used as ECR repository).   | *(Required)*               |
| `PRE_TEST_CHECK`   | Adds a pre-test suffix to tags if true.         | `true`                     |
| `BUILD_KIT`        | Enables BuildKit for Docker if set.             | *(Empty)*                  |

---

## Usage

### 1. Export Required Environment Variables

Ensure all required environment variables are set:
```bash
export REGION="us-east-1"
export TAG="my-tag"
export ACCOUNT_ID="123456789012"
export SERVICE_NAME="my-service"
```

### 2. Run the Script

Execute the script to validate requirements, build the Docker image, and push it to ECR:
```bash
./build_and_push.sh
```

---

## Script Workflow

### 1. **Validation**
- Ensures `SERVICE_NAME` is set.
- Installs AWS CLI if missing.
- Verifies the existence of the specified ECR repository.

### 2. **ECR Login**
- Logs in to AWS ECR using the AWS CLI.

### 3. **Docker Image Build**
- Builds the Docker image using the specified Dockerfile path and context.
- Supports custom build arguments and platforms.

### 4. **Image Tagging and Pushing**
- Determines the tag based on the GitHub reference type (branch or tag).
- Tags and pushes the image to ECR.
- Adds additional tags (e.g., commit SHA) for non-release builds.
- Exports output variables for GitHub Actions.

---

## Logging

The script provides detailed logs for each step. Logs are categorized into:
- **INFO**: Informational messages.
- **ERROR**: Critical errors that cause the script to exit.

---

## Example GitHub Workflow

This script can be integrated into a GitHub Actions workflow:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v3

      - name: Set Up AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: arn:aws:iam::123456789012:role/MyRole
          aws-region: us-east-1

      - name: Run Build and Push Script
        env:
          REGION: us-east-1
          TAG: my-tag
          ACCOUNT_ID: 123456789012
          SERVICE_NAME: my-service
        run: |
          chmod +x ./build_and_push.sh
          ./build_and_push.sh
```

---

## Troubleshooting

### Common Issues

1. **ECR Repository Not Found**
   Ensure the repository exists in AWS ECR and the correct `SERVICE_NAME` is provided.

2. **AWS CLI Installation Fails**
   Ensure the script has sufficient permissions to install software.

3. **Docker Build Fails**
   Verify the `DOCKERFILE_PATH` and `DOCKERFILE_CONTEXT` values.

4. **Tagging Issues**
   Check the `GITHUB_REF_NAME` and `GITHUB_REF_TYPE` values.

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

