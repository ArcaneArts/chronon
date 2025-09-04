FROM n8nio/n8n:latest

# Switch to root to install system packages
USER root

# Install build dependencies (Python for node-gyp, plus compilers)
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++ \
    gcc

# Switch to the node user
USER node

# Set working directory to where community nodes are installed
WORKDIR /home/node/.n8n/custom

# Install the community nodes via npm
RUN npm install \
    n8n-nodes-qdrant@latest \
    n8n-nodes-webpage-content-extractor@latest \
    n8n-nodes-globals@latest \
    n8n-nodes-text-manipulation@latest \
    @elevenlabs/n8n-nodes-elevenlabs@latest \
    n8n-nodes-edit-image-plus@latest \
    @kenkaiii/n8n-nodes-supercode@latest

# Switch back to the default working directory
WORKDIR /data

# Clean up build dependencies (switch to root for apk del)
USER root
RUN apk del .build-deps
USER node