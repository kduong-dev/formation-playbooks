# Go backend service, built from the directory holding every app repo
# (formation-playbooks' parent). APP_DIR is the backend module within it,
# SERVICE the cmd/<dir> to build.
ARG SERVICE
ARG PORT

FROM golang:1.27-alpine AS builder
ARG APP_DIR
ARG SERVICE
WORKDIR /workspace
RUN apk add --no-cache git
COPY ${APP_DIR}/go.mod ${APP_DIR}/go.sum ./
RUN go mod download
COPY ${APP_DIR} .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/service ./cmd/${SERVICE}

FROM alpine:3.20
ARG PORT
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/service ./service
EXPOSE ${PORT}
ENTRYPOINT ["/app/service"]
