ARG SERVICE
ARG PORT

FROM golang:1.27-alpine AS builder
ARG SERVICE
WORKDIR /workspace
COPY reMarkableShelf/backend/go.mod reMarkableShelf/backend/go.sum ./
RUN go mod download
COPY reMarkableShelf/backend .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/service ./cmd/${SERVICE}

FROM alpine:3.20
ARG PORT
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /app/service ./service
EXPOSE ${PORT}
ENTRYPOINT ["/app/service"]
