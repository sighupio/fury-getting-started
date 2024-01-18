FROM alpine:3.17

LABEL maintainer="Ramiro Algozino <ramiro@sighup.io>"

ENV GLIBC_VER 2.35-r0
ENV AWSCLI_VERSION 2.8.12
ENV GCLOUD_VERSION 412.0.0
ENV TERRAFORM_VERSION 1.4.6
ENV KUBECTL_VERSION v1.26.3
ENV KUSTOMIZE_VERSION v3.10.0
ENV FURYCTL_VERSION v0.27.1
ENV FURYAGENT_VERSION v0.3.0
ENV VELERO_VERSION v1.10.0
ENV DIRENV_VERSION v2.32.2
ENV HELM_VERSION v3.12.3

RUN apk --update --no-cache add \
  bash \
  ca-certificates \
  curl \
  jq \
  git \
  openssh-client \
  python3 \
  py3-pip \
  openvpn \
  tar \
  wget \
  vim \
  nano \
  make \
  make \
  tree \
  bind-tools \
  openssl \
  bash-completion

RUN pip3 install --upgrade pip

RUN curl -sL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$${GLIBC_VER}/glibc-$${GLIBC_VER}.apk && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$${GLIBC_VER}/glibc-bin-$${GLIBC_VER}.apk && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/$${GLIBC_VER}/glibc-i18n-$${GLIBC_VER}.apk && \
    apk add --force-overwrite --virtual .glibc glibc-$${GLIBC_VER}.apk glibc-bin-$${GLIBC_VER}.apk glibc-i18n-$${GLIBC_VER}.apk && \
    /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8 && \
    curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$${AWSCLI_VERSION}.zip -o awscliv2.zip && \
    unzip awscliv2.zip && \
    aws/install && \
    apk add gcompat || true

# Install gcloud
RUN curl -L https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz -o /tmp/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
    mkdir -p /usr/local/gcloud && \
    tar -zxf /tmp/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz -C /usr/local/gcloud/ && \
    rm /tmp/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz

ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Install Terraform
RUN curl -L https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/ && \
    rm /tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install kubectl
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Install kustomize
RUN curl -L https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz -o /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz && \
    tar -zxf /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz -C /usr/local/bin/ && \
    rm /tmp/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz

# Install helm
RUN curl -LOs https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
  tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz && \
  mv linux-amd64/helm /usr/local/bin/helm && \
  rm -rf linux-amd64/

# Install furyctl
RUN curl -L https://github.com/sighupio/furyctl/releases/download/${FURYCTL_VERSION}/furyctl-linux-amd64 -o /usr/local/bin/furyctl && \
  chmod +x /usr/local/bin/furyctl

# Install furyagent
RUN curl -L https://github.com/sighupio/furyagent/releases/download/${FURYAGENT_VERSION}/furyagent-linux-amd64 -o /usr/local/bin/furyagent && \
  chmod +x /usr/local/bin/furyagent

# Install velero cli
RUN curl -L https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz -o /tmp/velero-${VELERO_VERSION}-linux-amd64.tar.gz && \
    tar -zxf /tmp/velero-${VELERO_VERSION}-linux-amd64.tar.gz -C /tmp/ && \
    mv /tmp/velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin && \
    rm /tmp/velero-${VELERO_VERSION}-linux-amd64.tar.gz && rm -rf /tmp/velero-${VELERO_VERSION}-linux-amd64

# Install direnv
RUN curl -L https://github.com/direnv/direnv/releases/download/${DIRENV_VERSION}/direnv.linux-amd64 -o /usr/local/bin/direnv && \
  chmod +x /usr/local/bin/direnv

# Create a group and user
RUN addgroup -S fury && adduser -S fury -G fury
RUN mkdir /demo && chown -R fury:fury /demo && chmod -R 755 /demo
USER fury

# Configure .bashrc
COPY src/.bashrc /home/fury/

WORKDIR /demo

CMD ["/bin/bash"]
