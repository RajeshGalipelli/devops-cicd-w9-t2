FROM python:3.12-alpine

RUN apk update \
    && apk upgrade \
    && rm -rf /var/cache/apk/*

RUN addgroup -g 10001 appgroup \
    && adduser -D -u 10001 -G appgroup -s /sbin/nologin appuser

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --no-compile -r requirements.txt

COPY app.py .

RUN chown -R appuser:appgroup /app

USER 10001:10001

EXPOSE 5000

CMD ["python", "app.py"]
