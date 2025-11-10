FROM mcr.microsoft.com/devcontainers/base:noble

# Install terraform CLI, tflint, terraform-docs, tfsec

# Set architecture variable
# Set versions as arguments
ARG TARGETARCH=arm64
ARG TERRAFORM_VERSION="1.13.4"
ARG TERRAFORM_DOCS_VERSION="0.20.0"
ARG TFSEC_VERSION="1.28.14"
ARG TERRASCAN_VERSION="1.19.9"
ARG TFLINT_VERSION="0.59.1"
ARG TFLINT_AWS_RULESET_VERSION="0.23.1"
ARG TFLINT_AZURE_RULESET_VERSION="0.23.0"
ARG TFLINT_GCP_RULESET_VERSION="0.23.1"
ARG INFRACOST_VERSION="0.10.42"
ARG CHECKOV_VERSION="3.2.489"
ARG VAULT_RADAR_VERSION="0.36.0"
ARG INSTALL_VAULT_RADAR="true"

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    gnupg \
    npm \
    git \
    gh \
    jq \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform CLI
# RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
#     && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
#     && apt-get update \
#     && apt-get install -y terraform \
#     && rm -rf /var/lib/apt/lists/*

# Install terraform-docs
# RUN TERRAFORM_DOCS_VERSION=$(curl -s https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | grep tag_name | cut -d '"' -f 4) \
#     && wget https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz \
#     && tar -xzf terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz \
#     && chmod +x terraform-docs \
#     && mv terraform-docs /usr/local/bin/ \
#     && rm terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz

# Install tflint
# RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install tfsec
# RUN TFSEC_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/tfsec/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//') \
#     && wget https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz \
#     && tar -xzf tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz \
#     && chmod +x tfsec \
#     && mv tfsec /usr/local/bin/tfsec \
#     && rm tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz

# Copy library scripts
COPY library-scripts/*.sh /tmp/library-scripts/
# COPY ALPHA library files
#COPY library-scripts/alpha/* /tmp/library-scripts/alpha/
RUN chmod +x /tmp/library-scripts/*.sh

# Install go
# RUN GO_VERSION=1.21.3 \
#     && wget https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz \
#     && tar -xzf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz \
#     && mv go /usr/local/ \
#     && rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz

# Set Go environment variables
# ENV PATH="/usr/local/go/bin:${PATH}"
# ENV GOPATH="/go"
# ENV PATH="${GOPATH}/bin:${PATH}"

# Install terraform-mcp-server from source
# RUN go install github.com/hashicorp/terraform-mcp-server/cmd/terraform-mcp-server@latest \
#     && mv ${GOPATH}/bin/terraform-mcp-server /usr/local/bin/terraform-mcp-server

USER vscode

# Install uv and pre-commit for the vscode user
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc \
    && $HOME/.local/bin/uv tool install pre-commit \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

RUN ~/.local/bin/uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

RUN sudo mkdir -p /workspace && \
  sudo chown -R $USER:$USER /workspace 

# Install cloud CLI tools
RUN /tmp/library-scripts/cloud-cli-tools.sh

RUN /tmp/library-scripts/terraform-tools.sh \
    "${TERRAFORM_VERSION}" \
    "${TERRAFORM_DOCS_VERSION}" \
    "${TFSEC_VERSION}" \
    "${TERRASCAN_VERSION}" \
    "${TFLINT_VERSION}" \
    "${TFLINT_AWS_RULESET_VERSION}" \
    "${TFLINT_AZURE_RULESET_VERSION}" \
    "${TFLINT_GCP_RULESET_VERSION}" \
    "${INFRACOST_VERSION}" \
    "${CHECKOV_VERSION}" \
    "${VAULT_RADAR_VERSION}" \
    "${INSTALL_VAULT_RADAR}"

