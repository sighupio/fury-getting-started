FROM alpine:3.10

LABEL maintainer="niccolo@sighup.io"

ENV AWSCLI_VERSION 1.19
ENV GCLOUD_VERSION 344.0.0
ENV TERRAFORM_VERSION 1.0.1
ENV KUBECTL_VERSION v1.19.2
ENV KUSTOMIZE_VERSION v3.6.1
ENV FURYCTL_VERSION v0.5.3
ENV FURYAGENT_VERSION v0.2.3
ENV VELERO_VERSION v1.6.0
ENV DIRENV_VERSION v2.28.0

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
  bash-completion

RUN pip3 install --upgrade pip
RUN pip3 install requests awscli==${AWSCLI_VERSION}

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
RUN mkdir /demo
RUN chown -R fury:fury /demo
RUN chmod -R 755 /demo
USER fury

# Configure .bashrc
COPY src/.bashrc /home/fury/

WORKDIR /demo

CMD ["/bin/bash"]
