FROM ubuntu:22.04

# Install core dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    build-essential \
    sudo \
    openjdk-17-jdk

# Import RVM GPG keys and install RVM
RUN gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB && \
    curl -sSL https://get.rvm.io | bash -s stable

# Setup RVM environment
ENV PATH="/usr/local/rvm/bin:/usr/local/rvm/rubies/default/bin:/usr/local/rvm/gems/default/bin:${PATH}"
RUN bash -c 'echo "source /etc/profile.d/rvm.sh" >> /etc/profile && \
    echo "source /usr/local/rvm/scripts/rvm" >> /etc/profile'

# Setup Java
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
RUN update-alternatives --set java ${JAVA_HOME}/bin/java && \
    update-alternatives --set javac ${JAVA_HOME}/bin/javac

# Setup Logstash
WORKDIR /opt/logstash
RUN git clone https://github.com/elastic/logstash && \
    cd logstash && \
    bash -c 'source /etc/profile.d/rvm.sh && \
    source /usr/local/rvm/scripts/rvm && \
    JRUBY_VERSION=$(cat .ruby-version) && \
    rvm install $JRUBY_VERSION && \
    rvm use $JRUBY_VERSION --default && \
    gem install rake && \
    export OSS=1 && \
    export LOGSTASH_SOURCE=1 && \
    export LOGSTASH_PATH=$(pwd) && \
    ./gradlew installDevelopmentGems && \
    rake bootstrap'

# Setup plugin workspace
WORKDIR /workspaces/logstash-output-datadog_logs

# Set environment variables
ENV LOGSTASH_SOURCE=1
ENV LOGSTASH_PATH=/opt/logstash/logstash
