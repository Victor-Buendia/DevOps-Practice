FROM python:3.8-slim AS app
FROM python:3.8 AS build

FROM app
WORKDIR /app
COPY ./requirements.txt ./
RUN pip install --quiet --no-cache-dir -r requirements.txt

COPY . .
CMD [ "python", "/app/src/main.py" ]