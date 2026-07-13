FROM python:3.11-slim

LABEL org.opencontainers.image.source="https://github.com/yourusername/model-supply-chain"
LABEL org.opencontainers.image.description="Secure ML model server with supply chain verification"

WORKDIR /app

# Install security tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Cosign for runtime verification
RUN curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 && \
    mv cosign-linux-amd64 /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Copy model artifacts (with signatures and attestations)
COPY artifacts/ ./artifacts/

# Create non-root user
RUN useradd -m -u 1000 modeluser && \
    chown -R modeluser:modeluser /app

USER modeluser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Start server with signature verification enabled by default
CMD ["python", "src/model_server.py"]
