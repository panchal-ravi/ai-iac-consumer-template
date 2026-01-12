FROM srlynch1/terraform-ai-tools:latest

RUN npm install -g @anthropic-ai/claude-code ccstatusline && \
    npm cache clean --force

# Create Claude configuration directory and configure status line for node user
RUN mkdir -p /home/node/.claude && \
    echo '{"statusLine": "ccstatusline"}' > /home/node/.claude/settings.json && \
    mkdir -p /home/node/.config/ccstatusline && \
    chown -R node:node /home/node/.claude /home/node/.config/ccstatusline

# Configure ccstatusline with Powerline enabled
RUN echo '{\
  "version": 3,\
  "lines": [\
    [\
      {\
        "id": "1",\
        "type": "model",\
        "color": "cyan"\
      },\
      {\
        "id": "2",\
        "type": "separator"\
      },\
      {\
        "id": "3",\
        "type": "context-length",\
        "color": "brightBlack"\
      },\
      {\
        "id": "4",\
        "type": "separator"\
      },\
      {\
        "id": "5",\
        "type": "git-branch",\
        "color": "magenta"\
      },\
      {\
        "id": "6",\
        "type": "separator"\
      },\
      {\
        "id": "7",\
        "type": "git-changes",\
        "color": "yellow"\
      }\
    ],\
    [],\
    []\
  ],\
  "flexMode": "full-minus-40",\
  "compactThreshold": 60,\
  "colorLevel": 2,\
  "inheritSeparatorColors": false,\
  "globalBold": false,\
  "powerline": {\
    "enabled": true,\
    "separators": [\
      ""\
    ],\
    "separatorInvertBackground": [\
      false\
    ],\
    "startCaps": [""],\
    "endCaps": [""],\
    "autoAlign": true,\
    "theme": "gruvbox"\
  },\
  "defaultPadding": "     "\
}' > /home/node/.config/ccstatusline/settings.json && \
    chown node:node /home/node/.config/ccstatusline/settings.json

# Add clauded alias for claude -dangerously-skip-permissions
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /home/node/.zshrc && \
    chown node:node /home/node/.zshrc
