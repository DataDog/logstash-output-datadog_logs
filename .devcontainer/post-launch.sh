#!/bin/bash
set -e

# Setup plugin
cd /workspaces/logstash-output-datadog_logs/logstash-output-datadog_logs

# Use correct JRuby version
source /etc/profile.d/rvm.sh
source /usr/local/rvm/scripts/rvm
rvm use $(cat "${LOGSTASH_PATH}/.ruby-version")

# Install dependencies and run tests
bundle install
bundle exec rake vendor
bundle exec rspec 