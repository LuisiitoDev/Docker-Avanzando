FROM python:3-slim as build-env
COPY . /app
WORKDIR /app

FROM gcr.io/distroless/python3
COPY --from=build-env /app /app
WORKDIR /app
CMD ["hello.py", "/etc"]