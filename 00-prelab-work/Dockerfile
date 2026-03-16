FROM mcr.microsoft.com/azurelinux/base/python:3

ARG TERRAFORM_VERSION=1.13.5
ARG ARCH=amd64

RUN tdnf -y install ca-certificates git jq curl nginx vim net-tools bind-utils tcpdump zip unzip gettext azure-cli
RUN curl -fSLo /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip \
 && unzip -d /usr/local/bin /tmp/terraform.zip \
 && rm /tmp/terraform.zip \
 && terraform -version

RUN ln -sf /usr/bin/python3 /usr/local/bin/python
COPY startup.sh /startup.sh

ENTRYPOINT [ "/startup.sh" ]