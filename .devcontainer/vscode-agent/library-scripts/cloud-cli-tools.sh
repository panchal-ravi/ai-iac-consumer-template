#!/usr/bin/env bash
set -e

# This script installs AWS CLI, Azure CLI, and Google Cloud SDK

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        AWS_ARCH="x86_64"
        ;;
    aarch64|arm64)
        AWS_ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH, using AWS CLI for: $AWS_ARCH"
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip
unzip -qq /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Google Cloud SDK
echo "Installing Google Cloud SDK..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get install -y google-cloud-cli

# # Create directories for credentials
mkdir -p $HOME/.aws
mkdir -p $HOME/.azure
mkdir -p $HOME/.config/gcloud

# Set proper ownership
chown -R $USER:$USER $HOME/.aws
chown -R $USER:$USER $HOME/.azure
chown -R $USER:$USER $HOME/.config/gcloud

echo "Cloud CLI tools installation complete!"
