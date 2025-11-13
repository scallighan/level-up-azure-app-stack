FROM mcr.microsoft.com/azure-cli:azurelinux3.0

ARG TERRAFORM_VERSION=1.13.5
ARG ARCH=amd64

RUN tdnf -y install git jq curl nginx vim net-tools bind-utils tcpdump zip unzip
RUN curl -fSLo /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip \
 && unzip -d /usr/local/bin /tmp/terraform.zip \
 && rm /tmp/terraform.zip \
 && terraform -version


ENTRYPOINT [ "nginx", "-g", "daemon off;" ]