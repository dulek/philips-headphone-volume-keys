# Copyright 2026 Michał Dulko
# SPDX-License-Identifier: Apache-2.0
# Build-container setup adapted from Gathin23/cleanyourtv (MIT); see THIRD_PARTY_NOTICES.md.
FROM eclipse-temurin:17-jdk

ARG CMDLINE_TOOLS=11076708
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    GRADLE_USER_HOME=/gradle \
    ANDROID_USER_HOME=/gradle/.android \
    HOME=/gradle

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$ANDROID_HOME/cmdline-tools" \
    && curl -fsSL \
       "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip" \
       -o /tmp/android-tools.zip \
    && unzip -q /tmp/android-tools.zip -d "$ANDROID_HOME/cmdline-tools" \
    && mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest" \
    && rm /tmp/android-tools.zip

ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" \
    && mkdir -p /gradle/.android \
    && chmod 777 /gradle /gradle/.android \
    && chmod -R a+rX "$ANDROID_HOME"

WORKDIR /workspace
