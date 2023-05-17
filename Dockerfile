FROM quay.io/costoolkit/releases-teal:luet-toolchain-0.33.0-2 AS luet
FROM registry.opensuse.org/isv/rancher/harvester/baseos53/main/baseos:latest AS base

ARG K3S_VERSION=v1.26.4+k3s1
ARG ARCH=amd64
ENV ARCH=${ARCH}

# Necessary for luet to run
ENV LUET_NOLOCK=true

# Copy luet from the official images
COPY --from=luet /usr/bin/luet /usr/bin/luet
COPY files/etc/luet/luet.yaml /etc/luet/luet.yaml
RUN luet install -y \
    system/cos-setup \
    system/immutable-rootfs \
    system/grub2-config \
    system/base-dracut-modules \
    system/grub2-efi-image \
    system/grub2-artifacts \
    selinux/k3s \
    toolchain/yq \
    toolchain/yip \
    toolchain/luet

# Install k3s server/agent
ENV INSTALL_K3S_VERSION=${K3S_VERSION}
RUN curl -sfL https://get.k3s.io > installer.sh && \
    INSTALL_K3S_SKIP_START="true" INSTALL_K3S_SKIP_ENABLE="true" sh installer.sh && \
    INSTALL_K3S_SKIP_START="true" INSTALL_K3S_SKIP_ENABLE="true" sh installer.sh agent && \
    rm -rf installer.sh

## System layout

# Create the folder for journald persistent data
RUN mkdir -p /var/log/journal

# Required by k3s etc.
RUN mkdir /usr/libexec && touch /usr/libexec/.keep

# Copy custom files
COPY files/ /

# Generate initrd
RUN mkinitrd

# OS level configuration
RUN echo "VERSION=6666" > /etc/os-release
RUN echo "GRUB_ENTRY_NAME=K3COS" >> /etc/os-release
RUN echo "welcome to our K3COS" >> /etc/issue.d/01-k3cos

# Download nerdctl
ARG NERDCTL_VERSION=1.2.1
RUN curl -o ./nerdctl-bin.tar.gz -sfL "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz"
RUN tar -zxvf nerdctl-bin.tar.gz && mv nerdctl /usr/bin/
RUN rm -f nerdctl-bin.tar.gz containerd-rootless-setuptool.sh containerd-rootless.sh
