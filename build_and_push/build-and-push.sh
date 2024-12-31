#!/bin/bash

set -euo pipefail  # Enable strict error handling

################################################################################
# Configuration
################################################################################

# Default environment variables with validation
declare -A CONFIG=(
    [REGION]="${REGION:-us-east-1}" ###here you can put default AWS region where to build image or delete default value
    [TAG]="${TAG:-pre-test}"
    [DOCKERFILE_PATH]="${DOCKERFILE_PATH:-.}"
    [DOCKERFILE_CONTEXT]="${DOCKERFILE_CONTEXT:-.}"
    [ACCOUNT_ID]="${ACCOUNT_ID:-<123456789012>}" ###here you can put default AWS account ID where to build image or delete default value
    [SERVICE_NAME]="${SERVICE_NAME:-""}"
    [PRE_TEST_CHECK]="${PRE_TEST_CHECK:-true}"
    [BUILD_KIT]="${BUILD_KIT:-""}"
)

# Derived configuration
ECR_NAME="${CONFIG[ACCOUNT_ID]}.dkr.ecr.${CONFIG[REGION]}.amazonaws.com"
REPO_NAME="${ECR_NAME}/${CONFIG[SERVICE_NAME]}"
INITIAL_TAG="${REPO_NAME}:$(echo "${GITHUB_SHA}" | cut -c1-8)"
COMMIT_SHA="commit-${GITHUB_SHA}"

################################################################################
# Logging Functions
################################################################################

function log_info() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - INFO - $1"
}

function log_error() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - ERROR - $1" >&2
}

function exit_with_error() {
    log_error "$1"
    exit 1
}

################################################################################
# Validation Functions
################################################################################

function validate_requirements() {
    if [[ -z "${CONFIG[SERVICE_NAME]}" ]]; then
        exit_with_error "SERVICE_NAME environment variable is required"
    fi

    if ! command -v aws >/dev/null 2>&1 && ! install_aws_cli; then
        exit_with_error "Failed to install AWS CLI"
    fi
}

function validate_ecr_repository() {
    if ! aws ecr describe-repositories \
        --repository-names "${CONFIG[SERVICE_NAME]}" \
        --region "${CONFIG[REGION]}" >/dev/null 2>&1; then
        exit_with_error "ECR repository ${REPO_NAME} does not exist"
    fi
    log_info "ECR repository ${REPO_NAME} exists"
}

################################################################################
# Setup Functions
################################################################################

function install_aws_cli() {
    log_info "Installing AWS CLI..."
    local temp_dir=$(mktemp -d)

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        -o "${temp_dir}/awscliv2.zip" >/dev/null 2>&1 || return 1

    unzip "${temp_dir}/awscliv2.zip" -d "${temp_dir}" >/dev/null 2>&1 || return 1
    sudo sh "${temp_dir}/aws/install" >/dev/null 2>&1 || return 1

    rm -rf "${temp_dir}"
    log_info "AWS CLI installed successfully"
    return 0
}

function setup_ecr_login() {
    log_info "Logging into ECR: ${REPO_NAME}"
    if ! aws ecr get-login-password --region "${CONFIG[REGION]}" | \
        docker login --username AWS --password-stdin "${ECR_NAME}"; then
        exit_with_error "ECR login failed"
    fi
    log_info "ECR login successful"
}

################################################################################
# Docker Build Functions
################################################################################

function build_docker_image() {
    local platform_arg=""
    if [[ -n "${PLATFORM:-}" ]]; then
        platform_arg="--platform linux/arm64"
        log_info "Using platform: ${platform_arg}"
    fi

    log_info "Building image: ${INITIAL_TAG}"
    local build_cmd="${CONFIG[BUILD_KIT]} docker build -t ${INITIAL_TAG} \
        ${CONFIG[DOCKERFILE_PATH]} ${DOCKER_BUILD_ARGS:-} \
        ${CONFIG[DOCKERFILE_CONTEXT]} ${platform_arg}"

    log_info "Build command: ${build_cmd}"
    if ! eval "${build_cmd}"; then
        exit_with_error "Docker build failed"
    fi
}

################################################################################
# Tag Management Functions
################################################################################

function determine_tag_name() {
    local pre_test_suffix=""
    [[ ${CONFIG[PRE_TEST_CHECK]} == true ]] && pre_test_suffix="-pre-test"

    case "${GITHUB_REF_TYPE}" in
        "branch")
            if [[ "${GITHUB_REF_NAME}" == "main" ]]; then ###here you put you main/master branch name
                echo "${GITHUB_REF_NAME}${pre_test_suffix}"
            elif [[ "${GITHUB_REF_NAME}" =~ ^[0-9]+\/merge$ ]]; then
                local pr_num=$(echo "${GITHUB_REF_NAME}" | cut -d'/' -f1)
                echo "pr-${pr_num}${pre_test_suffix}"
            else
                echo "$(echo "${GITHUB_REF_NAME}" | sed 's/[_|\/]/-/g')${pre_test_suffix}"
            fi
            ;;
        "tag")
            if [[ "${GITHUB_REF_NAME}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
                echo "${GITHUB_REF_NAME}"
            else
                echo "$(echo "${GITHUB_REF_NAME}" | sed 's/[_|\/]/-/g')${pre_test_suffix}"
            fi
            ;;
        *)
            echo "$(echo "${GITHUB_REF_NAME}" | sed 's/[_|\/]/-/g')${pre_test_suffix}"
            ;;
    esac
}

################################################################################
# Push Functions
################################################################################

function push_docker_image() {
    local tag_name=$(determine_tag_name)
    log_info "Using tag: ${tag_name}"

    # Pull and tag the image
    docker pull "${INITIAL_TAG}"
    docker tag "${INITIAL_TAG}" "${REPO_NAME}:${tag_name}"
    docker push "${REPO_NAME}:${tag_name}"

    # Add commit SHA tag for non-release builds
    if [[ ! "${GITHUB_REF_TYPE}" == "tag" || ! "${GITHUB_REF_NAME}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        docker tag "${INITIAL_TAG}" "${REPO_NAME}:${COMMIT_SHA}"
        docker push "${REPO_NAME}:${COMMIT_SHA}"
        log_info "Pushed tags: ${tag_name} and ${COMMIT_SHA}"
    else
        log_info "Pushed tag: ${tag_name}"
    fi

    # Export variables for GitHub Actions
    {
        echo "tag_name=${tag_name}"
        echo "commit_sha=${COMMIT_SHA}"
        echo "image_uri=${REPO_NAME}:${tag_name}"
    } >> "${GITHUB_OUTPUT}"
}

################################################################################
# Main Execution
################################################################################

function main() {
    validate_requirements
    validate_ecr_repository
    setup_ecr_login
    build_docker_image
    push_docker_image
}

# Execute main function
main