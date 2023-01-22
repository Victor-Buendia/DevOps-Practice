FROM python:3.8-slim AS app
FROM python:3.8 AS build

ARG PIP_NO_CACHE_DIR=off
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="${PATH}:/root/.local/bin"
RUN poetry config virtualenvs.create false

WORKDIR /app
COPY gces-bib ./

WORKDIR /app/gces-bib
RUN poetry install -q --no-root
RUN poetry build -q

FROM app
WORKDIR /app
COPY ./requirements.txt ./
RUN pip install --quiet --no-cache-dir -r requirements.txt

COPY . .
CMD [ "python", "/app/src/main.py" ]