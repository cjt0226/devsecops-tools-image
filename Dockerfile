# Use a base image to build (and download) the tools on
FROM alpine as build

LABEL maintainer="frank.chen@homecredit.cn"

COPY requirements.txt .

# Install necessary binaries
RUN apk --update --upgrade --no-cache add ca-certificates curl git unzip py3-pip gcc

# Create virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

## Install wheel first, as that is not installed by default
#RUN pip3 install wheel
## Install packages as specified in the requirements.txt file
#RUN pip3 install --upgrade pip
RUN pip3 install --upgrade pip && pip3 install -r requirements.txt --upgrade --ignore-installed six

# Download and unzip sonar-scanner-cli
RUN curl -sL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.6.2.2472-linux.zip -o /tmp/scanner.zip && \
    unzip /tmp/scanner.zip -d /tmp/sonarscanner && \
    mv /tmp/sonarscanner/sonar-scanner-4.6.2.2472-linux /usr/lib/sonar-scanner && \
    sed -i 's/use_embedded_jre=true/use_embedded_jre=false/g' /usr/lib/sonar-scanner/bin/sonar-scanner

# Clone nikto.pl
RUN git clone --depth=1 https://github.com/sullo/nikto /tmp/nikto && \
    rm -rf /tmp/nikto/program/.git && \
    mv /tmp/nikto/program /usr/lib/nikto

# Clone testssl.sh
RUN git clone --depth=1 https://github.com/drwetter/testssl.sh /tmp/testssl && \
    mkdir /usr/lib/testssl && \
    mv /tmp/testssl/bin/openssl.Linux.x86_64 /usr/lib/testssl/openssl && \
    chmod ugo+x /usr/lib/testssl/openssl && \
    mv /tmp/testssl/etc/ /usr/lib/testssl/etc/ && \
    mv /tmp/testssl/testssl.sh /usr/lib/testssl/testssl.sh && \
    chmod ugo+x /usr/lib/testssl/testssl.sh

FROM alpine as release
COPY --from=build /opt/venv /opt/venv
COPY --from=build /usr/lib/nikto/ /usr/lib/nikto/
COPY --from=build /usr/lib/sonar-scanner/ /usr/lib/sonar-scanner/
COPY --from=build /usr/lib/testssl/ /usr/lib/testssl/
RUN ln -s /usr/lib/nikto/nikto.pl /usr/local/bin/nikto.pl
RUN ln -s /usr/lib/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner
RUN ln -s /usr/lib/testssl/testssl.sh /usr/local/bin/testssl.sh

# Install necessary binaries
RUN apk --update --upgrade --no-cache add curl git python3 procps npm perl openjdk8

# Update node package manager
RUN npm install --global npm@latest

ENV PATH="/opt/venv/bin:$PATH"
ENV SONAR_RUNNER_HOME=/usr/lib/sonar-scanner SONAR_USER_HOME=/tmp
ENV LC_ALL=C.UTF-8
ENV ANCHORE_CLI_URL=http://anchore-engine_api_1:8228/v1 ANCHORE_CLI_USER=admin ANCHORE_CLI_PASS=foobar

# adduser jenkins for dind, if use jenkins's docker,use args "--volume /etc/passwd:/etc/passwd:ro" to map jenkins user to container
RUN addgroup -S tool && \
    adduser tool -S -G tool && \
    chown -R tool:tool /opt/venv &&\
    addgroup -g 1000 jenkins && \
    adduser jenkins -u 1000 -G jenkins -D
USER tool