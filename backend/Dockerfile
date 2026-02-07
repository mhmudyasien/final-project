# =========================
# Build stage
# =========================
FROM python:3.11-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    postgresql-dev \
    python3-dev \
    libffi-dev

COPY requirements.txt .

# Install dependencies, switching to psycopg2 source for size
RUN pip install --no-cache-dir --prefix=/install \
    $(grep -vE "pytest|psycopg2-binary" requirements.txt) psycopg2

# Prune builder artifacts (Keeping .dist-info as it's required for runtime)
RUN find /install -name "*.pyc" -delete && \
    find /install -name "__pycache__" -type d -exec rm -rf {} +

# =========================
# Production stage
# =========================
FROM alpine:3.18

WORKDIR /app

# Install native python3, libpq and curl for healthchecks
RUN apk add --no-cache \
    python3 \
    libpq \
    curl \
    && rm -rf /usr/lib/python3.11/idlelib \
    /usr/lib/python3.11/tkinter \
    /usr/lib/python3.11/unittest \
    /usr/lib/python3.11/turtledemo \
    /usr/lib/python3.11/turtle.py \
    /usr/lib/python3.11/pydoc_data \
    /usr/lib/python3.11/distutils \
    /usr/lib/python3.11/lib2to3 \
    /usr/lib/python3.11/config-3.11-x86_64-linux-musl \
    /usr/lib/python3.11/test \
    /usr/lib/python3.11/__pycache__ \
    && find /usr/lib/python3.11 -name "*.pyc" -delete \
    && find /usr/lib/python3.11 -name "__pycache__" -type d -exec rm -rf {} +

# Copy installed packages from builder
COPY --from=builder /install/lib/python3.11/site-packages /usr/lib/python3.11/site-packages
COPY . .

# Final prune of application dependencies (keeping metadata)
RUN rm -rf /usr/lib/python3.11/site-packages/sqlalchemy/testing \
    /usr/lib/python3.11/site-packages/flask_swagger_ui/static/swagger-ui-master/dist/*.map

# Environment variables
ENV FLASK_APP=app.py
ENV FLASK_ENV=production
ENV PYTHONUNBUFFERED=1

EXPOSE 5000

CMD ["python3", "app.py"]
