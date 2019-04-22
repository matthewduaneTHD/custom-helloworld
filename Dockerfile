### HOW TO USE THIS
# This is intended to remove the local machine, and any inconsistencies, from the android build process.
# The following examples assume the `docker build` command is given a URL which has a Dockerfile at the base level
# and a folder (`dockerScripts`) with a script named `entry<something>`.
# Keep in mind running the image created by the dockerfile will create a folder named `gen` which will contain the generated apk.
# 1. docker build -t [__your image name:your tag__] [__URL here#branch name here__]
#     a) example: docker build --no-cache --squash -t apkbuilder:latest git@github.com:matthewduaneTHD/docker-android.git#master
# 2. docker run -v "$(pwd)"/gen:/gen --env BRANCH=[__your branch here__] --env SSH_PRIVATE_KEY="[__your ssh private key__] --env REPO_SSH_URL="[__your git repo here__]" __your image name:__
#     example) docker run -v "$(pwd)"/gen:/gen --env BRANCH="$(git rev-parse --abbrev-ref HEAD)" --env SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" --env REPO_SSH_URL="git@github.homedepot.com:OneSupplyChain/Shell.git" apkbuilder
#       HINT: "$(git rev-parse --abbrev-ref HEAD)" for current branch name; can just use "master" if thats what you want.
# 3. run `adb uninstall com.homedepot.osc.shell`
#   WAIT FOR THIS TO COMPLETE...
# 4. run `adb install -r ./gen/app.apk`
# 5. ??? 
# 6. PROFIT
######################################
# TL;DR:
# docker build --no-cache --squash -t apkbuilder:latest git@github.com:matthewduaneTHD/docker-android.git#master
# docker run -v "$(pwd)"/gen:/gen --env BRANCH="$(git rev-parse --abbrev-ref HEAD)" --env SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" --env REPO_SSH_URL="git@<yourgithub>.git" apkbuilder
# adb uninstall <your_app>
# adb install -r ./gen/app.apk

# # ---------------------------------------------------------------------------------------------------------------------------------
FROM openjdk:8-slim

ARG android_v
# ARG android_sdkv
ARG android_btv
ARG paging=MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM\\nMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM\\n

# # Environment variables - to be set during docker build using args
ENV ANDROID_VERSION ${android_v:-22}
# ENV SDK_TOOLS_VERSION ${android_sdkv:-25.2.5}
ENV ANDROID_BUILD_TOOLS_VERSION ${android_btv:-28.0.3}
# # Environment variables - set during docker run
ENV SSH_PRIVATE_KEY=ERRORsetOnDockerRunCommand
ENV BRANCH=ERRORsetOnDockerRunCommand
ENV REPO_SSH_URL=ERRORsetOnDockerRunCommand
# # Environment variables to leave alone
ENV CODE_REPO /Shell
ENV ANDROID_HOME /lib/android-sdk
ENV PATH ${PATH}:${ANDROID_HOME}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools
# ENV ANDROID_SDK_HOME $ANDROID_HOME


# Install necessary linux tools to grab the sdk
RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    git \
    openssh-client \
    openssh-server \
    openssl \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# # add any self-signed certs to image
COPY certificates /certs/

RUN cp /certs/*.pem /etc/ssl/certs \
    && ls /etc/ssl/certs \
    && update-ca-certificates

RUN for i in /certs/*.cer; do keytool -importcert -alias homedepot -file "$i"  -keystore $(update-alternatives --query java | grep 'Value: ' | grep -o '/.*/jre')/lib/security/cacerts -storepass changeit --noprompt; done


# # Making directories and files that will be needed
ARG github_url=github.homedepot.com
RUN mkdir /gen/ \
# add github public keys to known hosts
    && mkdir ~/.ssh/ \
    && ssh-keyscan -t rsa "${github_url}" >> ~/.ssh/known_hosts \
    && mkdir /dockerEntry/

COPY dockerScripts/entry* /dockerEntry/entrypoint

WORKDIR ${ANDROID_HOME}

# # Install Android SDK
RUN echo | openssl s_client -showcerts -servername dl.google.com -connect dl.google.com:443 2>/dev/null | openssl x509 -inform pem -noout -text
# RUN wget -q http://dl.google.com/android/repository/tools_r${SDK_TOOLS_VERSION}-linux.zip -O android-sdk-tools.zip \
RUN wget -nv https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk-tools.zip \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME} \
    && rm -f android-sdk-tools.zip
# # Alternate way...
# RUN wget https://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
#     && tar -xvzf android-sdk_r24.4.1-linux.tgz \
#     && mv android-sdk-linux /usr/local/android-sdk \
#     && rm android-sdk_r24.4.1-linux.tgz

# # # Install/update Android tools
RUN echo 'Changing permissions for android sdk recursively' \
    && chmod -R 777 ${ANDROID_HOME}/tools \
    && printf "${paging}" \
    && echo 'Listing what is currently installed for SDK, then installing all tools' \
    && sdkmanager --list \
    && echo yes | sdkmanager "platform-tools"

COPY dockerScripts/installAndroidParts /tmp/
RUN /tmp/installAndroidParts "platforms;android-" "${ANDROID_VERSION}" \
    && /tmp/installAndroidParts "build-tools;" "${ANDROID_BUILD_TOOLS_VERSION}" \
    && rm /tmp/installAndroidParts

RUN printf "${paging}" \
    && echo 'Printing current list of installed tools' \
    && sdkmanager --list \
    && printf "${paging}" \
    && echo "SUCCESS!!!!!!!!! installing SDK"

# # Getting EMDK.zip to the image.
RUN mkdir ${ANDROID_HOME}/add-ons \
# https://www.zebra.com/content/dam/zebra_new_ia/en-us/software/developer-tools/emdk-for-android/EMDK-A-0609024-MAC.zip
    && wget -nv https://storage.googleapis.com/1sc_mercury_resources/EMDK_6.9.zip -O EMDK_6.9.zip \
# Unzip the file and put addon-symbol_emdk-symbol-{your platform version} to the right directory
    && unzip -q EMDK_6.9.zip -d ${ANDROID_HOME} \
    && ls -hAlt ${ANDROID_HOME}/EMDK_6.9 \
    && mv ${ANDROID_HOME}/EMDK_6.9/addon* ${ANDROID_HOME}/add-ons/ \
    && chmod -R 777 ${ANDROID_HOME}/add-ons \
    && ls -hAlt ${ANDROID_HOME}/add-ons/ \
    && rm -rf ${ANDROID_HOME}/EMDK_6.9 \
    && rm ${ANDROID_HOME}/EMDK_6.9.zip


WORKDIR ${CODE_REPO}

ENTRYPOINT [ "/dockerEntry/entrypoint" ]
