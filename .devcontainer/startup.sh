#!/bin/bash
set -e

# Import RVM GPG keys
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

# Install RVM
curl -sSL https://get.rvm.io | bash -s stable

# Add RVM to PATH and source it
echo 'source /etc/profile.d/rvm.sh' >> ~/.bashrc
echo 'source /usr/local/rvm/scripts/rvm' >> ~/.bashrc
source /etc/profile.d/rvm.sh
source /usr/local/rvm/scripts/rvm

# Install Java 17
apt-get update
apt-get install -y openjdk-17-jdk
update-alternatives --set java /usr/lib/jvm/java-17-openjdk-arm64/bin/java
update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-arm64/bin/javac
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64

# Setup directories
WORKSPACE_DIR="/workspaces/logstash-output-datadog_logs"
LOGSTASH_DIR="/opt/logstash"
mkdir -p $LOGSTASH_DIR
cd $LOGSTASH_DIR

# Clone Logstash first
if [ ! -d "logstash" ]; then
    git clone https://github.com/elastic/logstash
fi

# Install required JRuby version
cd logstash
JRUBY_VERSION=$(cat .ruby-version)
rvm install $JRUBY_VERSION
rvm use $JRUBY_VERSION --default
gem install rake

# Add RVM to PATH for current shell
export PATH="$PATH:/usr/local/rvm/bin"
export PATH="$PATH:/usr/local/rvm/rubies/$JRUBY_VERSION/bin"
export PATH="$PATH:/usr/local/rvm/gems/$JRUBY_VERSION/bin"

# Build Logstash
export OSS=1
export LOGSTASH_SOURCE=1
export LOGSTASH_PATH=$(pwd)
echo "export LOGSTASH_SOURCE=1" >> ~/.bashrc
echo "export LOGSTASH_PATH=$LOGSTASH_PATH" >> ~/.bashrc

echo "Running Gradle..."
./gradlew installDevelopmentGems

echo "Running rake..."
rake bootstrap

# Setup plugin
cd $WORKSPACE_DIR
cd logstash-output-datadog_logs

# Install dependencies and run tests
rvm use $(cat "${LOGSTASH_PATH}/.ruby-version")
bundle install
bundle exec rake vendor
bundle exec rspec

