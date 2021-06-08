FROM alpine:3.10

LABEL maintainer="niccolo@sighup.io"

ENV AWSCLI_VERSION 1.19
ENV TERRAFORM_VERSION 0.15.0
ENV KUBECTL_VERSION v1.19.2
ENV KUSTOMIZE_VERSION v3.6.1
ENV FURYCTL_VERSION v0.5.0
ENV FURYAGENT_VERSION v0.2.3

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
  make \
  tree \
  bind-tools

RUN pip3 install --upgrade pip
RUN pip3 install requests awscli==${AWSCLI_VERSION}

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

WORKDIR /demo

CMD ["/bin/bash"]
