#!/bin/bash
set -e

# Setup plugin
cd /workspaces/logstash-output-datadog_logs
echo "rvm_silence_path_mismatch_check_flag=1" >> /etc/profile.d/rvm.sh
echo "rvm use $(cat /opt/logstash/logstash/.ruby-version)" >> /etc/bash.bashrc
source ~/.bashrc
bundle install
bundle exec rake vendor