FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -o /gateway .
FROM alpine:3.22
WORKDIR /app
RUN adduser -D app && mkdir data && chown app:app data
COPY --from=build /gateway /app/gateway
USER app
ENV GATEWAY_ADDR=0.0.0.0:8080
EXPOSE 8080
CMD ["/app/gateway"]
