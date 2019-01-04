### HOW TO USE THIS
# this is intended to remove the local machine, and any inconsistencies, from the build process
# The following steps should be run from whichever directory has the dockerfile from OneSupplyChain/Shell GIT repo.
# Keep in mind it will create a folder named `gen` inside whatever folder you run it from
# 1. docker build -t [__your image name:your tag__] - < Dockerfile
#     a) example: docker build -t apkbuilder:latest - < Dockerfile
# 2. docker run -v "$(pwd)"/gen:/gen --env BRANCH=[__your branch here__] --env SSH_PRIVATE_KEY="[__your ssh private key__] --env REPO_SSH_URL="[__your git repo here__]" __your image name:__
#     example) docker run -v "$(pwd)"/gen:/gen --env BRANCH="$(git rev-parse --abbrev-ref HEAD)" --env SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" --env REPO_SSH_URL="git@github.homedepot.com:OneSupplyChain/Shell.git" apkbuilder
#       HINT: "$(git rev-parse --abbrev-ref HEAD)" for current branch name; can just use "master" if thats what you want.
# 3. run `adb uninstall com.homedepot.osc.shell`
#   WAIT FOR THIS TO COMPLETE...
# 4. run `adb install -r ./gen/app.apk`
# 5. ??? 
# 6. PROFIT
# 
# ###### MAKE SURE YOUR BRANCH HAS THE `./dockerScripts/entrypoint.sh` OTHERWISE THIS WILL BOMB ##########

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
    git \
    openssh-client \
    openssh-server \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${ANDROID_HOME}

# # Install Android SDK
# RUN wget -q http://dl.google.com/android/repository/tools_r${SDK_TOOLS_VERSION}-linux.zip -O android-sdk-tools.zip \
RUN wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O android-sdk-tools.zip \
    && unzip -q android-sdk-tools.zip -d ${ANDROID_HOME} \
    && rm -f android-sdk-tools.zip
# # Alternate way...
# RUN wget https://dl.google.com/android/android-sdk_r24.4.1-linux.tgz \
#     && tar -xvzf android-sdk_r24.4.1-linux.tgz \
#     && mv android-sdk-linux /usr/local/android-sdk \
#     && rm android-sdk_r24.4.1-linux.tgz

# # Install/update Android tools
RUN echo 'Changing permissions for android sdk recursively' \
&& echo $0 \
    && chmod -R 777 ${ANDROID_HOME}/tools \
    && printf "${paging}" \
    && echo 'Listing what is currently installed for SDK, then installing all tools' \
    && sdkmanager --list \
    && echo yes | sdkmanager "platform-tools" \
    && echo yes | sdkmanager "platforms;android-${ANDROID_VERSION}" \
    && echo yes | sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    && printf "${paging}" \
    && echo 'Printing current list of installed tools' \
    && sdkmanager --list \
    && printf "${paging}" \
    && echo "SUCCESS!!!!!!!!! installing SDK"

# # Getting EMDK.zip to the image.
RUN mkdir ${ANDROID_HOME}/add-ons \
    && wget -q https://storage.googleapis.com/1sc_mercury_resources/EMDK_6.9.zip -O EMDK_6.9.zip \
# Unzip the file and put addon-symbol_emdk-symbol-22 to the right directory
    && unzip -q EMDK_6.9.zip -d ${ANDROID_HOME} \
    && mv /${ANDROID_HOME}/EMDK_6.9/addon-symbol_emdk-symbol-22 /${ANDROID_HOME}/add-ons/

# # Making directories and files that will be needed
RUN mkdir /gen/ \
# add github public keys to known hosts
    && mkdir ~/.ssh/ \
    && ssh-keyscan -t rsa github.homedepot.com >> ~/.ssh/known_hosts

# # This may be really bad practice... But gotta get the script for entrypoint somehow.
ARG entry_script_url=https://raw.github.homedepot.com/OneSupplyChain/Shell/chore/161233796-pipeline-artifactory-apk-push/dockerScripts/entrypoint.sh?token=AAAcNmnRc2EN05bEAOwrTZf8jL2QzOK9ks5cJj65wA%3D%3D
# MASTER: https://raw.github.homedepot.com/OneSupplyChain/Shell/master/dockerScripts/entrypoint.sh?token=AAAcNotap_wsGPDRD9e0HBBtF0nkJRgRks5cJAsCwA%3D%3D
RUN mkdir /dockerEntry/ \
    && wget "${entry_script_url}" -O /dockerEntry/entrypoint \
## ALTERNATIVE (to wget a private THD git repo):
#     && touch /dockerEntry/entrypoint \
#     && printf '#!/bin/sh\n\
# echo "-----------entered entrypoint---------------"\n\
# echo "${SSH_PRIVATE_KEY}" > ~/.ssh/id_rsa \n\
# chmod 600 ~/.ssh/id_rsa \n\
# # Clone the repo, and JUST your repo.\n\
# git clone ${REPO_SSH_URL} --single-branch --branch ${BRANCH} ${CODE_REPO} \n\
# echo "-----------Verify by listing...---------------" \n\
# cd ${CODE_REPO} \n\
# ls -hAlt \n\
# sleep 5 \n\
# echo "---------------building apk------------------"\n\
# ./gradlew clean\n\
# ./gradlew cleanBuildCache\n\
# ./gradlew assembleRelease --stacktrace\n\
# echo "---------------moving apk------------------"\n\
# ls -hAlt /Shell/app/buildn\n\
# cp /Shell/app/build/*.apk /gen/app.apk\n\
# sleep 5 \n\
# echo "-----------end of entrypoint---------------"\n\
# exec "$@"\n' >> /dockerEntry/entrypoint \
    && chmod +x /dockerEntry/entrypoint \
    && cat /dockerEntry/entrypoint

WORKDIR ${CODE_REPO}

ENTRYPOINT [ "/dockerEntry/entrypoint" ]
