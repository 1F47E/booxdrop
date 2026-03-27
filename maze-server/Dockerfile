FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG SERVICE_VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o maze-server .

FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata
ENV TZ=UTC

WORKDIR /app
COPY --from=builder /app/maze-server .
COPY --from=builder /app/web ./web

EXPOSE 8085

CMD ["./maze-server"]
