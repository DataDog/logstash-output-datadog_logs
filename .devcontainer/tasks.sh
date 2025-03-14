#!/bin/bash

function run_tests() {
  bundle exec rspec "$@"
}

function build_gem() {
  gem build logstash-output-datadog_logs.gemspec
}

function install_gem() {
  version=$(grep VERSION lib/logstash/outputs/version.rb | sed -E 's/.*VERSION.+=.+["'\''](.*)['\''"].*/\1/')
  sudo /usr/share/logstash/bin/logstash-plugin install ./logstash-output-datadog_logs-${version}.gem
}

function check_logstash_running() {
  # Check if Logstash is already running and terminate it
  local pid=$(pgrep -f "logstash")
  if [ ! -z "$pid" ]; then
    echo "Found running Logstash instance (PID: $pid). Terminating..."
    sudo pkill -9 -f "logstash" 
    sleep 2
  fi
}

function run_logstash() {
  local config=${1:-"test/test.conf"}
  # Kill any existing Logstash processes
  check_logstash_running
  # Run with custom data directory to avoid conflicts
  sudo /usr/share/logstash/bin/logstash -f "$config" --path.data /tmp/logstash-data
}

function run_logstash_debug() {
  local config=${1:-"test/test.conf"}
  # Kill any existing Logstash processes
  check_logstash_running
  # For debugging purposes - use non-sudo version with custom data dir
  /usr/share/logstash/bin/logstash -f "$config" --path.data /tmp/logstash-data-debug
}

function show_help() {
  echo "Usage: tasks.sh [command]"
  echo ""
  echo "Available commands:"
  echo "  test          - Run all tests"
  echo "  test [file]   - Run specific test file"
  echo "  build         - Build the gem"
  echo "  install       - Install the gem to logstash"
  echo "  run [config]  - Run logstash with config (defaults to test/test.conf)"
  echo "  debug [config] - Run logstash in debug mode (no sudo)"
  echo "  help          - Show this help"
}

command=$1
shift

case $command in
  "test")
    run_tests "$@"
    ;;
  "build")
    build_gem
    ;;
  "install")
    install_gem
    ;;
  "run")
    run_logstash "$@"
    ;;
  "debug")
    run_logstash_debug "$@"
    ;;
  "help"|*)
    show_help
    ;;
esac 