FROM mcr.microsoft.com/devcontainers/base:noble

# Install terraform CLI, tflint, terraform-docs, tfsec

# Set architecture variable
ARG TARGETARCH=arm64

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    gnupg \
    npm \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform CLI
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Install terraform-docs
RUN TERRAFORM_DOCS_VERSION=$(curl -s https://api.github.com/repos/terraform-docs/terraform-docs/releases/latest | grep tag_name | cut -d '"' -f 4) \
    && wget https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz \
    && tar -xzf terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz \
    && chmod +x terraform-docs \
    && mv terraform-docs /usr/local/bin/ \
    && rm terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${TARGETARCH}.tar.gz

# Install tflint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Install tfsec
RUN TFSEC_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/tfsec/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//') \
    && wget https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz \
    && tar -xzf tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz \
    && chmod +x tfsec \
    && mv tfsec /usr/local/bin/tfsec \
    && rm tfsec_${TFSEC_VERSION}_linux_${TARGETARCH}.tar.gz

# Install go
RUN GO_VERSION=1.21.3 \
    && wget https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz \
    && tar -xzf go${GO_VERSION}.linux-${TARGETARCH}.tar.gz \
    && mv go /usr/local/ \
    && rm go${GO_VERSION}.linux-${TARGETARCH}.tar.gz

# Set Go environment variables
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# Install python3 and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Verify installations
# RUN terraform version \
#     && terraform-docs version \
#     && tflint --version \
#     && tfsec --version \
#     && go version

# Install terraform-mcp-server from source
RUN go install github.com/hashicorp/terraform-mcp-server/cmd/terraform-mcp-server@latest \
    && mv ${GOPATH}/bin/terraform-mcp-server /usr/local/bin/terraform-mcp-server
