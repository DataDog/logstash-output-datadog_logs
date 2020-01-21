# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2017 Datadog, Inc.

# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"

# DatadogLogs lets you send logs to Datadog
# based on LogStash events.
class LogStash::Outputs::DatadogLogs < LogStash::Outputs::Base

  config_name "datadog_logs"

  default :codec, "json"

  # Datadog configuration parameters
  config :api_key, :validate => :string, :required => true
  config :host, :validate => :string, :required => true, :default => 'http-intake.logs.datadoghq.com'
  config :port, :validate => :number, :required => true, :default => 443
  config :use_ssl, :validate => :boolean, :required => true, :default => true
  config :max_backoff, :validate => :number, :required => true, :default => 30
  config :max_retries, :validate => :number, :required => true, :default => 5
  config :use_http, :validate => :boolean, :required => false, :default => true
  config :use_compression, :validate => :boolean, :required => false, :default => true
  config :compression_level, :validate => :number, :required => false, :default => 6

  public
  def register
    require "socket"
    client = nil
    @codec.on_event do |event, payload|
      message = "#{@api_key} #{payload}\n"
      retries = 0
      backoff = 1
      begin
        client ||= new_client
        client.write(message)
      rescue => e
        @logger.warn("Could not send payload", :exception => e, :backtrace => e.backtrace)
        client.close rescue nil
        client = nil
        if retries < max_retries || max_retries < 0
          sleep backoff
          backoff = 2 * backoff unless backoff > max_backoff
          retries += 1
          retry
        end
        @logger.warn("Max number of retries reached, dropping the payload", :payload => payload, :max_retries => max_retries)
      end
    end
  end

  public
  def receive(event)
    # handle new event
    @codec.encode(event)
  end

  private
  def new_client
    # open a secure connection with Datadog
    if @use_ssl
      @logger.info("Starting SSL connection", :host => @host, :port => @port)
      socket = TCPSocket.new @host, @port
      sslSocket = OpenSSL::SSL::SSLSocket.new socket
      sslSocket.connect
      return sslSocket
    else
      @logger.info("Starting plaintext connection", :host => @host, :port => @port)
      return TCPSocket.new @host, @port
    end
  end

end
