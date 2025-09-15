FROM python:3.11-slim

# Keep Python output unbuffered and avoid writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system deps needed for some audio and crypto packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       gcc \
       libsndfile1 \
       ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements.txt \
    && pip install gunicorn

# Copy app sources
COPY . /app

ENV PORT=5000
EXPOSE 5000

# Use gunicorn to serve the Flask app. The module exposes `app` at
# real_time_voice.flask_app:app so gunicorn can import it directly.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "real_time_voice.flask_app:app", "--workers", "1", "--threads", "4"]
