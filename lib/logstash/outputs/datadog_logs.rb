# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2017 Datadog, Inc.

# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "zlib"

require_relative "version"

# DatadogLogs lets you send logs to Datadog
# based on LogStash events.
class LogStash::Outputs::DatadogLogs < LogStash::Outputs::Base

  # Respect limit documented at https://docs.datadoghq.com/api/latest/logs/#send-logs
  DD_MAX_BATCH_LENGTH = 1000
  DD_MAX_BATCH_SIZE = 5000000
  DD_TRUNCATION_SUFFIX = "...TRUNCATED..."

  config_name "datadog_logs"

  concurrency :shared

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
  config :force_v1_routes, :validate => :boolean, :required => false, :default => false # force using deprecated v1 routes
  config :http_proxy, :validate => :string, :required => false, :default => ""

  # Register the plugin to logstash
  public
  def register
    @client = new_client(@logger, @api_key, @use_http, @use_ssl, @no_ssl_validation, @host, @port, @use_compression, @force_v1_routes, @http_proxy)
  end

  # Logstash shutdown hook
  def close
    @client.close
  end

  # Entry point of the plugin, receiving a set of Logstash events
  public
  def multi_receive(events)
    return if events.empty?
    encoded_events = @codec.multi_encode(events)
    begin
      if @use_http
        batches = batch_http_events(encoded_events, DD_MAX_BATCH_LENGTH, DD_MAX_BATCH_SIZE)
        batches.each do |batched_event|
          process_encoded_payload(format_http_event_batch(batched_event))
        end
      else
        encoded_events.each do |encoded_event|
          process_encoded_payload(format_tcp_event(encoded_event.last, @api_key, DD_MAX_BATCH_SIZE))
        end
      end
    rescue => e
      if e.is_a?(InterruptedError)
        raise e
      else
        @logger.error("Uncaught processing exception in datadog forwarder #{e.message}")
      end
    end
  end

  # Process and send each encoded payload
  def process_encoded_payload(payload)
    if @use_compression and @use_http
      payload = gzip_compress(payload, @compression_level)
    end
    @client.send_retries(payload, @max_retries, @max_backoff)
  end

  # Format TCP event
  def format_tcp_event(payload, api_key, max_request_size)
    formatted_payload = "#{api_key} #{payload}"
    if (formatted_payload.bytesize > max_request_size)
      return truncate(formatted_payload, max_request_size)
    end
    formatted_payload
  end

  # Format HTTP events
  def format_http_event_batch(batched_events)
    "[#{batched_events.join(',')}]"
  end

  # Group HTTP events in batches
  def batch_http_events(encoded_events, max_batch_length, max_request_size)
    batches = []
    current_batch = []
    current_batch_size = 0
    encoded_events.each_with_index do |event, i|
      encoded_event = event.last
      current_event_size = encoded_event.bytesize
      # If this unique log size is bigger than the request size, truncate it
      if current_event_size > max_request_size
        encoded_event = truncate(encoded_event, max_request_size)
        current_event_size = encoded_event.bytesize
      end

      if (i > 0 and i % max_batch_length == 0) or (current_batch_size + current_event_size > max_request_size)
        batches << current_batch
        current_batch = []
        current_batch_size = 0
      end

      current_batch_size += encoded_event.bytesize
      current_batch << encoded_event
    end
    batches << current_batch
    batches
  end

  # Truncate events over the provided max length, appending a marker when truncated
  def truncate(event, max_length)
    if event.length > max_length
      event = event[0..max_length - 1]
      event[max(0, max_length - DD_TRUNCATION_SUFFIX.length)..max_length - 1] = DD_TRUNCATION_SUFFIX
      return event
    end
    event
  end

  def max(a, b)
    a > b ? a : b
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
  def new_client(logger, api_key, use_http, use_ssl, no_ssl_validation, host, port, use_compression, force_v1_routes, http_proxy)
    if use_http
      DatadogHTTPClient.new logger, use_ssl, no_ssl_validation, host, port, use_compression, api_key, force_v1_routes, http_proxy, -> { defined?(pipeline_shutdown_requested?) ? pipeline_shutdown_requested? : false }
    else
      DatadogTCPClient.new logger, use_ssl, no_ssl_validation, host, port
    end
  end

  class RetryableError < StandardError;
  end

  class InterruptedError < StandardError;
  end

  class DatadogClient
    def send_retries(payload, max_retries, max_backoff)
      backoff = 1
      retries = 0
      begin
        send(payload)
      rescue RetryableError => e
        if retries < max_retries || max_retries < 0
          @logger.warn("Retrying send due to: #{e.message}")
          interruptableSleep(backoff)
          backoff = 2 * backoff unless backoff > max_backoff
          retries += 1
          retry
        end
        @logger.error("Max number of retries reached, dropping message. Last exception: #{e.message}")
      rescue => ex
        if ex.is_a?(InterruptedError)
          raise ex
        else
          @logger.error("Unmanaged exception while sending log to datadog #{ex.message}")
        end
      end
    end

    def interruptableSleep(duration)
      amountSlept = 0
      while amountSlept < duration
        sleep 1
        amountSlept += 1
        if interrupted?
          raise InterruptedError.new "Interrupted while backing off"
        end
      end
    end

    def interrupted?
      false
    end

    def send(payload)
      raise NotImplementedError, "Datadog transport client should implement the send method"
    end

    def close
      raise NotImplementedError, "Datadog transport client should implement the close method"
    end
  end

  class DatadogHTTPClient < DatadogClient
    require "manticore"

    RETRYABLE_EXCEPTIONS = [
        ::Manticore::Timeout,
        ::Manticore::SocketException,
        ::Manticore::ClientProtocolException,
        ::Manticore::ResolutionFailure
    ]

    def initialize(logger, use_ssl, no_ssl_validation, host, port, use_compression, api_key, force_v1_routes, http_proxy, interruptedLambda = nil)
      @interruptedLambda = interruptedLambda
      @logger = logger
      protocol = use_ssl ? "https" : "http"

      @headers = {"Content-Type" => "application/json"}
      if use_compression
        @headers["Content-Encoding"] = "gzip"
      end

      if force_v1_routes
        @url = "#{protocol}://#{host}:#{port.to_s}/v1/input/#{api_key}"
      else
        @url = "#{protocol}://#{host}:#{port.to_s}/api/v2/logs"
        @headers["DD-API-KEY"] = api_key
        @headers["DD-EVP-ORIGIN"] = "logstash"
        @headers["DD-EVP-ORIGIN-VERSION"] = DatadogLogStashPlugin::VERSION
      end

      logger.info("Starting HTTP connection to #{protocol}://#{host}:#{port.to_s} with compression " + (use_compression ? "enabled" : "disabled") + (force_v1_routes ? " using v1 routes" : " using v2 routes"))

      config = {}
      config[:ssl][:verify] = :disable if no_ssl_validation
      if http_proxy != ""
        config[:proxy] = http_proxy
      end
      @client = Manticore::Client.new(config)
    end

    def interrupted?
      if @interruptedLambda
        return @interruptedLambda.call
      end

      false
    end

    def send(payload)
      begin
        response = @client.post(@url, :body => payload, :headers => @headers).call
        # in case of error or 429, we will retry sending this payload
        if response.code >= 500 || response.code == 429
          raise RetryableError.new "Unable to send payload: #{response.code} #{response.body}"
        end
        if response.code >= 400
          @logger.error("Unable to send payload due to client error: #{response.code} #{response.body}")
        end
      rescue => client_exception
        should_retry = retryable_exception?(client_exception)
        if should_retry
          raise RetryableError.new "Unable to send payload #{client_exception.message}"
        else
          raise client_exception
        end
      end

    end

    def retryable_exception?(exception)
      RETRYABLE_EXCEPTIONS.any? { |e| exception.is_a?(e) }
    end

    def close
      @client.close
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
      @send_mutex = Mutex.new
    end

    def connect
      if @use_ssl
        @logger.info("Starting SSL connection #{@host} #{@port}")
        socket = TCPSocket.new @host, @port
        ssl_context = OpenSSL::SSL::SSLContext.new
        if @no_ssl_validation
          ssl_context.set_params({:verify_mode => OpenSSL::SSL::VERIFY_NONE})
        end
        ssl_context = OpenSSL::SSL::SSLSocket.new socket, ssl_context
        ssl_context.connect
        ssl_context
      else
        @logger.info("Starting plaintext connection #{@host} #{@port}")
        TCPSocket.new @host, @port
      end
    end

    def send(payload)
      @send_mutex.synchronize do
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

    def close
      @socket.close rescue nil
    end
  end

end
