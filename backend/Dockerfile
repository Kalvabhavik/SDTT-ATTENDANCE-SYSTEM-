# Production Dockerfile for Attendrix Backend on Render / Cloud Container Platforms
FROM python:3.11-slim

WORKDIR /app

# Ensure python writes output directly to terminal without buffering
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

# Install minimal OS dependencies for network & healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy backend source code including app/models/*.onnx
COPY . .

# Expose port (Render overrides PORT environment variable at runtime)
EXPOSE 8000

# Healthcheck probing /api/health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/api/health || exit 1

# Start uvicorn bound to 0.0.0.0 and dynamically injected Render PORT
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
