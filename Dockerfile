FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (layer cache)
COPY requirements.txt .
RUN pip install --no-cache-dir --pre -r requirements.txt

# Copy application code
COPY app/ ./app/
COPY utils/ ./utils/
COPY data/ ./data/

# outputs/ is written at runtime — create the dir
RUN mkdir -p outputs

EXPOSE 8000

CMD ["gunicorn", "app.main:app", \
     "--workers", "1", \
     "--worker-class", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "120"]
