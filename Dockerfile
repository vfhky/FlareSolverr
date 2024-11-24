FROM debian:bullseye-slim AS builder

# Build dummy packages to skip installing them and their dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends equivs \
    && equivs-control libgl1-mesa-dri \
    && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: libgl1-mesa-dri\nVersion: 99.0.0\nDescription: Dummy package for libgl1-mesa-dri\n' >> libgl1-mesa-dri \
    && equivs-build libgl1-mesa-dri \
    && mv libgl1-mesa-dri_*.deb /libgl1-mesa-dri.deb \
    && equivs-control adwaita-icon-theme \
    && printf 'Section: misc\nPriority: optional\nStandards-Version: 3.9.2\nPackage: adwaita-icon-theme\nVersion: 99.0.0\nDescription: Dummy package for adwaita-icon-theme\n' >> adwaita-icon-theme \
    && equivs-build adwaita-icon-theme \
    && mv adwaita-icon-theme_*.deb /adwaita-icon-theme.deb \
    && apt-get purge -y --auto-remove equivs \
    && rm -rf /var/lib/apt/lists/*

# Add a build stage for Python packages
FROM debian:bullseye-slim AS python-builder

WORKDIR /build
COPY requirements.txt .

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-dev \
        build-essential \
        libxml2-dev \
        libxslt-dev \
    && pip3 wheel --no-cache-dir -r requirements.txt -w /wheels \
    && rm -rf /root/.cache /var/lib/apt/lists/*

FROM debian:bullseye-slim

# Copy dummy packages and pre-built wheels
COPY --from=builder /*.deb /
COPY --from=python-builder /wheels /wheels

WORKDIR /app
COPY requirements.txt .

# Install dummy packages and system dependencies
RUN apt-get update \
    && dpkg -i /libgl1-mesa-dri.deb \
    && dpkg -i /adwaita-icon-theme.deb \
    && apt-get install -f \
    && apt-get install -y --no-install-recommends \
        chromium \
        xvfb \
        dumb-init \
        procps \
        curl \
        vim \
        xauth \
        python3 \
        python3-pip \
        libxml2 \
        libxslt1.1 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/lib/x86_64-linux-gnu/libmfxhw* \
    && rm -f /usr/lib/x86_64-linux-gnu/mfx/* \
    && useradd --home-dir /app --shell /bin/sh flaresolverr \
    && chown -R flaresolverr:flaresolverr . \
    && pip3 install --no-index --find-links=/wheels -r requirements.txt \
    && rm -rf /root/.cache /wheels /tmp/*

USER flaresolverr

RUN mkdir -p "/app/.config/chromium/Crash Reports/pending"

COPY src .
COPY package.json ../

EXPOSE 8191
EXPOSE 8192

# dumb-init avoids zombie chromium processes
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["/usr/bin/python3", "-u", "/app/flaresolverr.py"]