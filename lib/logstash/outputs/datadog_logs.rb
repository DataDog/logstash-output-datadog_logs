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

  # Your Datadog API key
  config :api_key, :validate => :string, :required => true

  public
  def register
    require "socket"
    @host = "intake.logs.datadoghq.com"
    @port = 10516

    client_socket = nil
    @codec.on_event do |event, payload|
      # open a connection if needed and send JSON payload      
      begin
        client_socket = new_client_socket unless client_socket
        r,w,e = IO.select([client_socket], [client_socket], [client_socket], nil)
        client_socket.sysread(16384) if r.any?
        if w.any?
          # send message to Datadog
          message = "#{@api_key} #{payload}\n"
          client_socket.syswrite(message)
          @logger.debug("Sent", :payload => payload)
        end # w.any?
      rescue => e
        # close connection and always retry
        @logger.warn("TCP exception", :exception => e, :backtrace => e.backtrace)
        client_socket.close rescue nil
        client_socket = nil
        sleep 5
        retry
      end # begin
    end # @codec.on_event
  end # def register

  public
  def receive(event)
    # handle new event
    @codec.encode(event)
  end # def receive

  private
  def new_client_socket
    # open a secure connection with Datadog    
    begin      
      socket = TCPSocket.new @host, @port
      sslSocket = OpenSSL::SSL::SSLSocket.new socket
      sslSocket.connect
      @logger.debug("Started SSL connection", :host => @host)
      return sslSocket
    rescue => e
      # always retry when the connection failed
      @logger.warn("SSL exception", :exception => e, :backtrace => e.backtrace)
      sleep 5
      retry
    end # begin
  end # def new_client_socket

end # class LogStash::Outputs::DatadogLogs
