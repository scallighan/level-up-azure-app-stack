FROM mcr.microsoft.com/azurelinux/base/python:3

ARG TERRAFORM_VERSION=1.13.5
ARG ARCH=amd64

RUN tdnf -y install ca-certificates git jq curl nginx vim net-tools bind-utils tcpdump zip unzip gettext azure-cli libltdl libtool
RUN curl -fSLo /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip \
 && unzip -d /usr/local/bin /tmp/terraform.zip \
 && rm /tmp/terraform.zip \
 && terraform -version


RUN ln -sf /usr/bin/python3 /usr/local/bin/python
RUN pip install jupyterlab dockernel

RUN mkdir -p /etc/nginx/conf.d
RUN mkdir -p /etc/nginx/templates
#COPY nginx.conf /etc/nginx/

COPY jupyter_lab_config.py /root/.jupyter/

COPY startup.sh /startup.sh

#RUN tdnf search sql libtool > /output.txt

EXPOSE 80 8888

ENTRYPOINT [ "/startup.sh" ]