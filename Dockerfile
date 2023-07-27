FROM quay.io/luet/base:0.32.5 AS framework-build
COPY files/etc/luet/luet.yaml /etc/luet/luet.yaml
ENV LUET_NOLOCK=true

SHELL ["/usr/bin/luet", "install", "-y", "--system-target", "/framework"]

RUN system/cos-setup
RUN system/immutable-rootfs
RUN cloud-config/network
RUN cloud-config/recovery
RUN cloud-config/live
RUN cloud-config/boot-assessment
RUN cloud-config/default-services
RUN system/grub2-config
RUN system/base-dracut-modules
RUN system/grub2-efi-image
RUN system/grub2-artifacts

FROM ghcr.io/rancher/elemental-toolkit/elemental-cli:v0.10.7 AS elemental

# https://build.opensuse.org/package/show/SUSE:SLE-15-SP4:Update:Products:Micro54/SLE-Micro-Rancher
FROM registry.suse.com/suse/sle-micro-rancher/5.4

ARG K3S_VERSION=v1.26.6+k3s1
ARG ARCH=amd64
ENV ARCH=${ARCH}

# Copy installed files from the luet repos
COPY --from=framework-build /framework /

# Copy elemental cli
COPY --from=elemental /usr/bin/elemental /usr/bin/elemental

# Install k3s server/agent
ENV INSTALL_K3S_VERSION=${K3S_VERSION}
RUN curl -sfL https://get.k3s.io > installer.sh && \
    INSTALL_K3S_SKIP_START="true" INSTALL_K3S_SKIP_ENABLE="true" INSTALL_K3S_BIN_DIR="/usr/bin" INSTALL_K3S_SKIP_SELINUX_RPM="true" sh installer.sh && \
    INSTALL_K3S_SKIP_START="true" INSTALL_K3S_SKIP_ENABLE="true" INSTALL_K3S_BIN_DIR="/usr/bin" INSTALL_K3S_SKIP_SELINUX_RPM="true" sh installer.sh agent && \
    mkdir -p /opt/k3s && \
    curl -sfL https://github.com/k3s-io/k3s/releases/download/${INSTALL_K3S_VERSION}/k3s-airgap-images-amd64.tar.zst > /opt/k3s/k3s-airgap-images-amd64.tar.zst && \
    rm -rf installer.sh

## System layout

# Copy custom files
COPY files/ /

# Generate initrd with required elemental services
RUN mkinitrd

# OS level configuration
RUN echo "VERSION=6666" > /etc/os-release && \
    echo "GRUB_ENTRY_NAME=K3COS" >> /etc/os-release && \
    echo "Welcome to our K3COS" >> /etc/issue.d/01-k3cos

# Add nerdctl
ARG NERDCTL_VERSION=1.4.0
RUN curl -o ./nerdctl-bin.tar.gz -sfL "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz" && \
    tar -zxvf nerdctl-bin.tar.gz && mv nerdctl /usr/bin/ && \
    rm -f nerdctl-bin.tar.gz containerd-rootless-setuptool.sh containerd-rootless.sh

# Add kube-explorer
ARG KUBE_EXPLORER_VERSION=v0.3.3
RUN curl -o /usr/bin/kube-explorer -sfL https://github.com/cnrancher/kube-explorer/releases/download/${KUBE_EXPLORER_VERSION}/kube-explorer-linux-amd64 && \
    chmod +x /usr/bin/kube-explorer
