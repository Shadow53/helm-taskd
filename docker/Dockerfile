FROM alpine:latest

LABEL maintainer="shadow53@shadow53.com"

WORKDIR /taskd

EXPOSE 53589

VOLUME /taskd

ENV TASKDDATA=/taskd \
    TASKD_USERLIST=""

# All CA env variables are set to the defaults in the installed vars file
ENV CA_BITS=4096 \
    CA_EXPIRATION_DAYS=365 \
    CA_ORGANIZATION="Göteborg Bit Factory" \
    CA_CN=localhost \
    CA_COUNTRY=SE \
    CA_STATE="Västra Götaland" \
    CA_LOCALITY="Göteborg"

RUN addgroup -g 2000 taskd && \
    adduser -g "taskd user" \
    -h /taskd \
    -G taskd \
    -u 2000 \
    -D \
    -s /sbin/nologin \
    taskd

RUN chown -R taskd:taskd /taskd

RUN apk update && \
    apk upgrade && \
    apk add taskd taskd-pki

COPY --chown=taskd:taskd init.sh /init.sh

RUN chmod o+x /init.sh

USER taskd:taskd

ENTRYPOINT ["/init.sh"]
