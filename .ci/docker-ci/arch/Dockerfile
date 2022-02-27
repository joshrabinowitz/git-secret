FROM arch:latest

LABEL maintainer="mail@sobolevn.me"
LABEL vendor="git-secret team"

RUN pacman -S \
  # Direct dependencies:
  bash \
  gawk \
  git \
  gnupg \
  # Assumed to be present:
  file \
  make \
  procps

