FROM mcr.microsoft.com/azure-cli:azurelinux3.0

RUN tdnf -y install terraform git jq curl nginx vim net-tools bind-utils tcpdump

ENTRYPOINT [ "nginx", "-g", "daemon off;" ]