FROM scratch

COPY . .

CMD /bin/sh

ARG ORG=yushi3
ARG REPO=raspios-lite-docker-img

LABEL org.opencontainers.image.source https://github.com/${ORG}/${REPO}


