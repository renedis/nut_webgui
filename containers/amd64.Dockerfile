FROM --platform=linux/amd64 alpine:latest
RUN apk add --no-cache nut
RUN adduser -H -D -g "<nut_web>" nut_webgui
COPY --chmod=750 --chown=root:nut_webgui ./containers/server_start.sh /opt/nut_webgui/server_start.sh
COPY --chmod=750 --chown=root:nut_webgui ./bin/x86-64-musl/nut_webgui /opt/nut_webgui/nut_webgui
COPY --chmod=744 --chown=root:nut_webgui ./bin/static /opt/nut_webgui/static
WORKDIR /opt/nut_webgui
USER nut_webgui
CMD ["/opt/nut_webgui/server_start.sh"]
