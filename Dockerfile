FROM scratch

COPY . .

CMD /bin/sh

ARG ORG=casaroli
ARG REPO=raspios-lite-docker-img

LABEL org.opencontainers.image.source https://github.com/${ORG}/${REPO}


