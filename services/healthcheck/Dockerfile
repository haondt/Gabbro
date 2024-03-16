FROM alpine:latest

RUN apk --no-cache add curl

COPY ping.sh /config/ping.sh
RUN chmod +x /config/ping.sh

CMD ["sh", "-c", "/config/ping.sh"]
