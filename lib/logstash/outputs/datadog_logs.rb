# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2017 Datadog, Inc.

# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "zlib"


# DatadogLogs lets you send logs to Datadog
# based on LogStash events.
class LogStash::Outputs::DatadogLogs < LogStash::Outputs::Base

  # Respect limit documented at https://docs.datadoghq.com/agent/logs/?tab=tailexistingfiles#send-logs-over-https
  DD_MAX_BATCH_LENGTH = 200
  DD_MAX_BATCH_SIZE = 1000000

  config_name "datadog_logs"

  default :codec, "json"

  # Datadog configuration parameters
  config :api_key, :validate => :string, :required => true
  config :host, :validate => :string, :required => true, :default => "http-intake.logs.datadoghq.com"
  config :port, :validate => :number, :required => true, :default => 443
  config :use_ssl, :validate => :boolean, :required => true, :default => true
  config :max_backoff, :validate => :number, :required => true, :default => 30
  config :max_retries, :validate => :number, :required => true, :default => 5
  config :use_http, :validate => :boolean, :required => false, :default => true
  config :use_compression, :validate => :boolean, :required => false, :default => true
  config :compression_level, :validate => :number, :required => false, :default => 6
  config :no_ssl_validation, :validate => :boolean, :required => false, :default => false

  # Register the plugin to logstash
  public
  def register
    client ||= new_client(@logger, @api_key, @use_http, @use_ssl, @no_ssl_validation, @host, @port, @use_compression)
    @codec.on_event do |_, payload|
      payload = encode(payload, @use_http, @api_key)
      if @use_compression and @use_http
        payload = gzip_compress(payload, @compression_level)
      end
      client.send_retries(payload, @max_retries, @max_backoff)
    end
  end

  # Process a set of log events
  public
  def multi_receive(events)
    return if events.empty?
    if @use_http
      batches = batch_events(events, DD_MAX_BATCH_LENGTH, DD_MAX_BATCH_SIZE)
      batches.each do |batched_event|
        @codec.encode(batched_event)
      end
    else
      events.each do |event|
        @codec.encode(event)
      end
    end
  end

  # Encode payload for Datadog to the right format (no-op for HTTP)
  def encode(payload, use_http, api_key)
    if not use_http
      "#{api_key} #{payload}"
    else
      payload
    end
  end

  # Group events in batches
  def batch_events(events, max_batch_length, max_request_size)
    batches = []
    current_batch = []
    current_batch_size = 0
    events.each_with_index do |event, i|
      if (i > 0 and i % max_batch_length == 0) or (current_batch_size > max_request_size)
        batches << current_batch
        current_batch = []
        current_batch_size = 0
      end
      current_batch_size += event.get('message').bytesize
      current_batch << event
    end
    batches << current_batch
    batches
  end

  # Compress logs with GZIP
  def gzip_compress(payload, compression_level)
    gz = StringIO.new
    gz.set_encoding("BINARY")
    z = Zlib::GzipWriter.new(gz, compression_level)
    begin
      z.write(payload)
    ensure
      z.close
    end
    gz.string
  end

  # Build a new transport client
  def new_client(logger, api_key, use_http, use_ssl, no_ssl_validation, host, port, use_compression)
    if use_http
      DatadogHTTPClient.new logger, use_ssl, no_ssl_validation, host, port, use_compression, api_key
    else
      DatadogTCPClient.new logger, use_ssl, no_ssl_validation, host, port
    end
  end

  class RetryableError < StandardError;
  end

  class DatadogClient
    def send_retries(payload, max_retries, max_backoff)
      backoff = 1
      retries = 0
      begin
        send(payload)
      rescue RetryableError => e
        if retries < max_retries || max_retries < 0
          @logger.warn("Retrying ", :exception => e, :backtrace => e.backtrace)
          sleep backoff
          backoff = 2 * backoff unless backoff > max_backoff
          retries += 1
          retry
        end
      end
    end

    def send(payload)
    end
  end

  class DatadogHTTPClient < DatadogClient
    require "manticore"

    def initialize(logger, use_ssl, no_ssl_validation, host, port, use_compression, api_key)
      @logger = logger
      protocol = use_ssl ? "https" : "http"
      @url = "#{protocol}://#{host}:#{port.to_s}/v1/input/#{api_key}"
      @headers = {"Content-Type" => "application/json"}
      if use_compression
        @headers["Content-Encoding"] = "gzip"
      end
      logger.info("Starting HTTP connection to #{protocol}://#{host}:#{port.to_s} with compression " + (use_compression ? "enabled" : "disabled"))
      config = {}
      config[:ssl][:verify] = :disable if no_ssl_validation
      @client = Manticore::Client.new(config)
    end

    def send(payload)
      response = @client.post(@url, :body => payload, :headers => @headers).call
      if response.code >= 500
        raise RetryableError.new "Unable to send payload: #{response.code} #{response.body}"
      end
      if response.code >= 400
        @logger.error("Unable to send payload due to client error: #{response.code} #{response.body}")
      end
    end
  end

  class DatadogTCPClient < DatadogClient
    require "socket"

    def initialize(logger, use_ssl, no_ssl_validation, host, port)
      @logger = logger
      @use_ssl = use_ssl
      @no_ssl_validation = no_ssl_validation
      @host = host
      @port = port
    end

    def connect
      if @use_ssl
        @logger.info("Starting SSL connection #{@host} #{@port}")
        socket = TCPSocket.new @host, @port
        ssl_context = OpenSSL::SSL::SSLContext.new
        if @no_ssl_validation
          ssl_context.set_params({:verify_mode => OpenSSL::SSL::VERIFY_NONE})
        end
        ssl_context = OpenSSL::SSL::SSLSocket.new socket, sslContext
        ssl_context.connect
        ssl_context
      else
        @logger.info("Starting plaintext connection #{@host} #{@port}")
        TCPSocket.new @host, @port
      end
    end

    def send(payload)
      begin
        @socket ||= connect
        @socket.puts(payload)
      rescue => e
        @socket.close rescue nil
        @socket = nil
        raise RetryableError.new "Unable to send payload: #{e.message}."
      end
    end
  end

end
