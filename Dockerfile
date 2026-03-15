FROM katalonstudio/katalon:10-latest-slim

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      openssh-client \
      xvfb \
      curl \
      unzip \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# OPTIONAL: AWS CLI v2 (keep if your tests hit AWS/ECR/etc.)
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

WORKDIR /workspace

# Pattern A: Jenkins passes the katalonc command at runtime
ENTRYPOINT ["/bin/bash","-lc"]
