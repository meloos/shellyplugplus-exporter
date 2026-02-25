FROM python:3.12-alpine

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN addgroup -S app && adduser -S -G app app \
	&& chown -R app:app /app

USER app

EXPOSE 9924

CMD ["python", "app.py"]
