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
  config :api_key,     :validate => :string,  :required => true
  config :host,        :validate => :string,  :required => true, :default  => 'intake.logs.datadoghq.com'
  config :port,        :validate => :number,  :required => true, :default  => 10516
  config :use_ssl,     :validate => :boolean, :required => true, :default  => true
  config :max_backoff, :validate => :number,  :required => true, :default  => 30
  config :max_retries, :validate => :number,  :required => true, :default  => 5

  public
  def register
    require "socket"
    client = nil
    @codec.on_event do |event, payload|
      retries = 0
      begin
        if retries < max_retries
          if retries > 0
            backoff = 2 ** retries
            backoff = max_backoff unless backoff < max_backoff
            sleep backoff
          end
          client ||= new_client
          message = "#{@api_key} #{payload}\n"
          client.write(message)
        else
          @logger.warn("Max number of retries reached, dropping the payload", :payload => payload)
        end
      rescue => e
        # close connection and always retry
        @logger.warn("Could not send message, retrying", :exception => e, :backtrace => e.backtrace)
        client.close rescue nil
        client = nil
        retries += 1
        retry
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
