## 1. BUILD ARGS
# These allow changing the produced image by passing different build args to adjust
# the source from which your image is built.
# Build args can be provided on the commandline when building locally with:
#   podman build -f Containerfile --build-arg FEDORA_VERSION=40 -t local-image

# SOURCE_IMAGE arg can be anything from ublue upstream which matches your desired version:
# See list here: https://github.com/orgs/ublue-os/packages?repo_name=main
# - "silverblue"
# - "kinoite"
# - "sericea"
# - "onyx"
# - "lazurite"
# - "vauxite"
# - "base"
#
#  "aurora", "bazzite", "bluefin" or "ucore" may also be used but have different suffixes.
ARG SOURCE_IMAGE="aurora"

## SOURCE_SUFFIX arg should include a hyphen and the appropriate suffix name
# These examples all work for silverblue/kinoite/sericea/onyx/lazurite/vauxite/base
# - "-main"
# - "-nvidia"
# - "-asus"
# - "-asus-nvidia"
# - "-surface"
# - "-surface-nvidia"
#
# aurora, bazzite and bluefin each have unique suffixes. Please check the specific image.
# ucore has the following possible suffixes
# - stable
# - stable-nvidia
# - stable-zfs
# - stable-nvidia-zfs
# - (and the above with testing rather than stable)
ARG SOURCE_SUFFIX="-asus-nvidia"

## SOURCE_TAG arg must be a version built for the specific image: eg, 39, 40, gts, latest
ARG SOURCE_TAG="latest"


### 2. SOURCE IMAGE
## this is a standard Containerfile FROM using the build ARGs above to select the right upstream image
FROM ghcr.io/ublue-os/${SOURCE_IMAGE}${SOURCE_SUFFIX}:${SOURCE_TAG}


### 3. MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

# Setup Copr repos
RUN curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite.repo https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-bazzite-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite-multilib.repo https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite-multilib/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-bazzite-multilib-fedora-"${FEDORA_MAJOR_VERSION}".repo?arch=x86_64 && \
    ostree container commit

# Install kernel-fsync, if needed
RUN rpm-ostree cliwrap install-to-root / && \
    if [[ "${KERNEL_FLAVOR}" =~ "fsync" ]]; then \
        echo "will install ${KERNEL_FLAVOR} kernel from COPR" && \
        curl -Lo /etc/yum.repos.d/_copr_sentry-kernel-fsync.repo https://copr.fedorainfracloud.org/coprs/sentry/kernel-fsync/repo/fedora-$(rpm -E %fedora)/sentry-kernel-fsync-fedora-$(rpm -E %fedora).repo && \
        rpm-ostree override replace \
        --experimental \
        --from repo=copr:copr.fedorainfracloud.org:sentry:kernel-fsync \
            kernel \
            kernel-core \
            kernel-modules \
            kernel-modules-core \
            kernel-modules-extra \
            kernel-uki-virt \
            kernel-headers \
            kernel-devel \
    ; else \
        echo "will use kernel from ${KERNEL_FLAVOR} images" \
    ; fi && \
    ostree container commit

# Update packages that commonly cause build issues
RUN rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        vulkan-loader \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        alsa-lib \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        gnutls \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        glib2 \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        gtk3 \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        atk \
        at-spi2-atk \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libaom \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        gstreamer1 \
        gstreamer1-plugins-base \
        gstreamer1-plugins-bad-free-libs \
        gstreamer1-plugins-good-qt \
        gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free \
        gstreamer1-plugin-libav \
        gstreamer1-plugins-ugly-free \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        python3 \
        python3-libs \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libdecor \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libtirpc \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libuuid \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libblkid \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libmount \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        cups-libs \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libinput \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        libopenmpt \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        llvm-libs \
        || true && \
    rpm-ostree override replace \
    --experimental \
    --from repo=updates \
        fontconfig \
        || true && \
    rpm-ostree override remove \
        glibc32 \
        || true && \
    ostree container commit

# Install Valve's patched Mesa, Pipewire, Bluez, and Xwayland
# Install patched switcheroo control with proper discrete GPU support
RUN rpm-ostree override remove \
        mesa-va-drivers-freeworld && \
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:kylegospo:bazzite-multilib \
        mesa-filesystem \
        mesa-libxatracker \
        mesa-libglapi \
        mesa-dri-drivers \
        mesa-libgbm \
        mesa-libEGL \
        mesa-vulkan-drivers \
        mesa-libGL \
        pipewire \
        pipewire-alsa \
        pipewire-gstreamer \
        pipewire-jack-audio-connection-kit \
        pipewire-jack-audio-connection-kit-libs \
        pipewire-libs \
        pipewire-pulseaudio \
        pipewire-utils \
        bluez \
        bluez-obexd \
        bluez-cups \
        bluez-libs \
        xorg-x11-server-Xwayland && \
    rpm-ostree install \
        mesa-va-drivers-freeworld \
        mesa-vdpau-drivers-freeworld.x86_64 \
        libaacs \
        libbdplus \
        libbluray && \
    rpm-ostree override replace \
    --experimental \
    --from repo=copr:copr.fedorainfracloud.org:sentry:switcheroo-control_discrete \
        switcheroo-control && \
    ostree container commit

# Install Steam & Lutris, plus supporting packages
# Remove Feral gamemode, System76 Scheduler supersedes this
RUN rpm-ostree install \
        jupiter-sd-mounting-btrfs \
        at-spi2-core.i686 \
        atk.i686 \
        vulkan-loader.i686 \
        alsa-lib.i686 \
        fontconfig.i686 \
        gtk2.i686 \
        libICE.i686 \
        libnsl.i686 \
        libxcrypt-compat.i686 \
        libpng12.i686 \
        libXext.i686 \
        libXinerama.i686 \
        libXtst.i686 \
        libXScrnSaver.i686 \
        NetworkManager-libnm.i686 \
        nss.i686 \
        pulseaudio-libs.i686 \
        libcurl.i686 \
        systemd-libs.i686 \
        libva.i686 \
        libvdpau.i686 \
        libdbusmenu-gtk3.i686 \
        libatomic.i686 \
        pipewire-alsa.i686 \
        clinfo && \
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/fedora-updates.repo && \
    rpm-ostree install \
        mesa-vulkan-drivers.i686 \
        mesa-va-drivers-freeworld.i686 \
        mesa-vdpau-drivers-freeworld.i686 && \
    sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo && \
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree.repo && \
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-updates.repo && \
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-updates-testing.repo && \
    rpm-ostree install \
        steam && \
    sed -i '0,/enabled=1/s//enabled=0/' /etc/yum.repos.d/rpmfusion-nonfree-steam.repo && \
    sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree.repo && \
    sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-updates.repo && \
    sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree-updates-testing.repo && \
    sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/fedora-updates.repo && \
    rpm-ostree install \
        lutris \
        fluidsynth \
        fluid-soundfont-gm \
        qsynth \
        wxGTK \
        libFAudio \
        wine-core.x86_64 \
        wine-core.i686 \
        wine-pulseaudio.x86_64 \
        wine-pulseaudio.i686 \
        winetricks \
        protontricks \
        latencyflex-vulkan-layer \
        vkBasalt.x86_64 \
        vkBasalt.i686 \
        obs-vkcapture.x86_64 \
        obs-vkcapture.i686 \
        mangohud.x86_64 \
        mangohud.i686 && \
    if grep -q "kinoite" <<< "${BASE_IMAGE_NAME}"; then \
        rpm-ostree override remove \
            gamemode \
    ; else \
        rpm-ostree override remove \
            gamemode && \
        rpm-ostree override remove \
            gnome-shell-extension-gamemode \
            || true \
    ; fi && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/winetricks.desktop && \
    curl -Lo /tmp/latencyflex.tar.xz $(curl https://api.github.com/repos/ishitatsuyuki/LatencyFleX/releases/latest | jq -r '.assets[] | select(.name| test(".*.tar.xz$")).browser_download_url') && \
    mkdir -p /tmp/latencyflex && \
    tar --no-same-owner --no-same-permissions --no-overwrite-dir --strip-components 1 -xvf /tmp/latencyflex.tar.xz -C /tmp/latencyflex && \
    rm -f /tmp/latencyflex.tar.xz && \
    cp -r /tmp/latencyflex/wine/usr/lib/wine/* /usr/lib64/wine/ && \
    rm -rf /tmp/latencyflex && \
    curl -Lo /usr/bin/latencyflex https://raw.githubusercontent.com/KyleGospo/LatencyFleX-Installer/main/install.sh && \
    chmod +x /usr/bin/latencyflex && \
    sed -i 's@/usr/lib/wine/@/usr/lib64/wine/@g' /usr/bin/latencyflex && \
    sed -i 's@"dxvk.conf"@"/usr/share/latencyflex/dxvk.conf"@g' /usr/bin/latencyflex && \
    chmod +x /usr/bin/latencyflex && \
    ostree container commit

COPY build.sh /tmp/build.sh

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit
## NOTES:
# - /var/lib/alternatives is required to prevent failure with some RPM installs
# - All RUN commands must end with ostree container commit
#   see: https://coreos.github.io/rpm-ostree/container/#using-ostree-container-commit
