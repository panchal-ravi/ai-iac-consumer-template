#!/usr/bin/env bash
set -e

# This script installs Terraform and related tools

# Versions
TERRAFORM_VERSION=${1:-"1.12.1"}
TERRAFORM_DOCS_VERSION=${2:-"0.20.0"}
TFSEC_VERSION=${3:-"1.28.13"}
TERRASCAN_VERSION=${4:-"1.19.9"}
TFLINT_VERSION=${5:-"0.48.0"}
TFLINT_AWS_RULESET_VERSION=${6:-"0.23.1"}
TFLINT_AZURE_RULESET_VERSION=${7:-"0.23.0"}
TFLINT_GCP_RULESET_VERSION=${8:-"0.23.1"}
INFRACOST_VERSION=${9:-"0.10.41"}
CHECKOV_VERSION=${10:-"3.2.439"}
TERRAFORM_ALPHA=${11:-"false"}

if [ "$TERRAFORM_ALPHA" = "true" ]; then
    # echo "Installing Terraform Alpha binaries from library-scripts/alpha directory..."
    
    # # Get the directory where this script is located
    # SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # ALPHA_DIR="${SCRIPT_DIR}/alpha"
    # ls -la "${ALPHA_DIR}/"
    
    # # Find terraform alpha binary (pre-extracted, accepting Darwin binaries for Mac-only setup)
    # if [ -f "${ALPHA_DIR}/terraform" ]; then
    #     echo "Found Terraform alpha binary: terraform"
    #     sudo cp "${ALPHA_DIR}/terraform" /usr/local/bin/
    #     sudo chmod +x /usr/local/bin/terraform
    #     echo "Terraform alpha binary installed to /usr/local/bin/"
    # else
    #     echo "Error: No Terraform alpha binary found in ${ALPHA_DIR}"
    #     echo "Looking for: terraform (pre-extracted binary)"
    #     echo "Available files:"
    #     ls -la "${ALPHA_DIR}/" 2>/dev/null || echo "Directory not accessible"
    #     exit 1
    # fi
    
    # # Find tfpolicy alpha binary if it exists (pre-extracted)
    # if [ -f "${ALPHA_DIR}/tfpolicy" ]; then
    #     echo "Found TFPolicy alpha binary: tfpolicy"
    #     sudo cp "${ALPHA_DIR}/tfpolicy" /usr/local/bin/
    #     sudo chmod +x /usr/local/bin/tfpolicy
    #     echo "TFPolicy alpha binary installed to /usr/local/bin/"
    # else
    #     echo "Warning: No TFPolicy alpha binary found in ${ALPHA_DIR}"
    #     echo "Looking for: tfpolicy (pre-extracted binary)"
    # fi
else
    echo "Installing Terraform v${TERRAFORM_VERSION}..."
    curl -sSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    unzip -qq /tmp/terraform.zip -d /tmp
    sudo mv /tmp/terraform /usr/local/bin/
    rm -f /tmp/terraform.zip
fi

echo "Installing terraform-docs v${TERRAFORM_DOCS_VERSION}..."
curl -sSLo /tmp/terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp
sudo mv /tmp/terraform-docs /usr/local/bin/
rm -f /tmp/terraform-docs.tar.gz

echo "Installing tfsec v${TFSEC_VERSION}..."
curl -sSLo /tmp/tfsec "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64"
sudo mv /tmp/tfsec /usr/local/bin/
sudo chmod +x /usr/local/bin/tfsec

echo "Installing terrascan v${TERRASCAN_VERSION}..."
curl -sSLo /tmp/terrascan.tar.gz "https://github.com/tenable/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_x86_64.tar.gz"
tar -xzf /tmp/terrascan.tar.gz -C /tmp
sudo mv /tmp/terrascan /usr/local/bin/
rm -f /tmp/terrascan.tar.gz

echo "Installing tflint v${TFLINT_VERSION}..."
curl -sSLo /tmp/tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
unzip -qq /tmp/tflint.zip -d /tmp
sudo mv /tmp/tflint /usr/local/bin/
rm -f /tmp/tflint.zip

echo "Installing TFLint AWS ruleset v${TFLINT_AWS_RULESET_VERSION}..."
mkdir -p ~/.tflint.d/plugins
curl -sSLo /tmp/tflint-aws-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-aws/releases/download/v${TFLINT_AWS_RULESET_VERSION}/tflint-ruleset-aws_linux_amd64.zip"
unzip -qq /tmp/tflint-aws-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-aws-ruleset.zip

echo "Installing TFLint Azure ruleset v${TFLINT_AZURE_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-azure-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/download/v${TFLINT_AZURE_RULESET_VERSION}/tflint-ruleset-azurerm_linux_amd64.zip"
unzip -qq /tmp/tflint-azure-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-azure-ruleset.zip

echo "Installing TFLint GCP ruleset v${TFLINT_GCP_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-gcp-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${TFLINT_GCP_RULESET_VERSION}/tflint-ruleset-google_linux_amd64.zip"
unzip -qq /tmp/tflint-gcp-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-gcp-ruleset.zip

# Install Go if not already installed
# if ! command -v go &> /dev/null; then
#     echo "Installing Go (required for Terratest)..."
#     GO_VERSION="1.20.5"
#     curl -sSLo /tmp/go.tar.gz "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
#     sudo tar -C /usr/local -xzf /tmp/go.tar.gz
#     echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/node/.bashrc
#     echo 'export PATH=$PATH:$HOME/go/bin' >> /home/node/.bashrc
#     rm -f /tmp/go.tar.gz
# fi

echo "Installing Infracost v${INFRACOST_VERSION}..."
curl -sSLo /tmp/infracost.tar.gz "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-amd64.tar.gz"
tar -xzf /tmp/infracost.tar.gz -C /tmp
sudo mv /tmp/infracost-linux-amd64 /usr/local/bin/infracost
rm -f /tmp/infracost.tar.gz

echo "Installing pre-commit..."
# Install pre-commit system-wide using uv
uv tool install pre-commit --with pre-commit-uv

# Create a symlink so it's available system-wide
sudo ln -sf ~/.local/bin/pre-commit /usr/local/bin/pre-commit

# Also make sure it's available to the node user by installing it for them too
# First ensure the node user's .local directory exists
sudo -u node mkdir -p /home/node/.local/bin

# Install pre-commit for the node user (this will work after uv is installed for node user)
# We'll do this in the Dockerfile after switching to node user

echo "Installing Checkov v${CHECKOV_VERSION} in virtual environment..."
# Install python3-venv if not already installed
sudo apt-get update && sudo apt-get install -y python3-venv

# Create a virtual environment for Checkov
VENV_DIR="/opt/checkov-venv"
sudo python3 -m venv ${VENV_DIR}

# Install Checkov in the virtual environment
sudo ${VENV_DIR}/bin/pip install checkov==${CHECKOV_VERSION}


# Create a wrapper script for Checkov
sudo tee /usr/local/bin/checkov > /dev/null << EOL
#!/bin/bash
${VENV_DIR}/bin/checkov \$@
EOL

# Make the wrapper executable
sudo chmod +x /usr/local/bin/checkov

# Create .tflint.hcl config file
mkdir -p /home/node/.tflint.d
cat > /home/node/.tflint.hcl << EOF
plugin "aws" {
  enabled = true
}

plugin "azurerm" {
  enabled = true
}

plugin "google" {
  enabled = true
}
EOF

# Set ownership for the config file
chown -R node:node /home/node/.tflint.d

echo "Terraform tools installation complete!"
