FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN groupadd --gid 10001 companyos \
    && useradd \
        --uid 10001 \
        --gid companyos \
        --create-home \
        --shell /usr/sbin/nologin \
        companyos

COPY requirements.txt ./requirements.txt

RUN pip install --no-cache-dir --requirement requirements.txt

COPY --chown=companyos:companyos app ./app

USER companyos

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]
