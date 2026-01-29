FROM panchalravi/terraform-ai-tools:latest

ARG COPILOT_VERSION=0.0.398

RUN npm install -g @github/copilot@${COPILOT_VERSION} && \
    npm cache clean --force
