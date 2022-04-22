# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2017 Datadog, Inc.

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/datadog_logs"
require 'webmock/rspec'

describe LogStash::Outputs::DatadogLogs do
  context "should register" do
    it "with an api key" do
      plugin = LogStash::Plugin.lookup("output", "datadog_logs").new({"api_key" => "xxx"})
      expect { plugin.register }.to_not raise_error
    end

    it "without an api key" do
      expect { LogStash::Plugin.lookup("output", "datadog_logs").new() }.to raise_error(LogStash::ConfigurationError)
    end
  end

  subject do
    plugin = LogStash::Plugin.lookup("output", "datadog_logs").new({"api_key" => "xxx"})
    plugin.register
    plugin
  end

  context "when truncating" do
    it "should truncate messages of the given length" do
      input = "foobarfoobarfoobarfoobar"
      expect(subject.truncate(input, 15).length).to eq(15)
    end

    it "should replace the end of the message with a marker when truncated" do
      input = "foobarfoobarfoobarfoobar"
      expect(subject.truncate(input, 15)).to end_with("...TRUNCATED...")
    end

    it "should return the marker if the message length is smaller than the marker length" do
      input = "foobar"
      expect(subject.truncate(input, 1)).to eq("...TRUNCATED...")
    end

    it "should do nothing if the input length is smaller than the given length" do
      input = "foobar"
      expect(subject.truncate(input, 15)).to eq("foobar")
    end
  end

  context "when using HTTP" do
    it "should respect the batch length and create one batch of one event" do
      input_events = [[LogStash::Event.new({"message" => "dd"}), "dd"]]
      expect(subject.batch_http_events(input_events, 1, 1000).length).to eq(1)
    end

    it "should respect the batch length and create two batches of one event" do
      input_events = [[LogStash::Event.new({"message" => "dd1"}), "dd1"], [LogStash::Event.new({"message" => "dd2"}), "dd2"]]
      actual_events = subject.batch_http_events(input_events, 1, 1000)
      expect(actual_events.length).to eq(2)
      expect(actual_events[0][0]).to eq("dd1")
      expect(actual_events[1][0]).to eq("dd2")
    end

    it "should respect the request size and create two batches of one event" do
      input_events = [[LogStash::Event.new({"message" => "dd1"}), "dd1"], [LogStash::Event.new({"message" => "dd2"}), "dd2"]]
      actual_events = subject.batch_http_events(input_events, 10, 3)
      expect(actual_events.length).to eq(2)
      expect(actual_events[0][0]).to eq("dd1")
      expect(actual_events[1][0]).to eq("dd2")
    end

    it "should respect the request size and create two batches of two events" do
      input_events = [[LogStash::Event.new({"message" => "dd1"}), "dd1"], [LogStash::Event.new({"message" => "dd2"}), "dd2"], [LogStash::Event.new({"message" => "dd3"}), "dd3"], [LogStash::Event.new({"message" => "dd4"}), "dd4"]]
      actual_events = subject.batch_http_events(input_events, 6, 6)
      expect(actual_events.length).to eq(2)
      expect(actual_events[0][0]).to eq("dd1")
      expect(actual_events[0][1]).to eq("dd2")
      expect(actual_events[1][0]).to eq("dd3")
      expect(actual_events[1][1]).to eq("dd4")
    end

    it "should truncate events whose length is bigger than the max request size" do
      input_events = [[LogStash::Event.new({"message" => "dd1"}), "dd1"], [LogStash::Event.new({"message" => "foobarfoobarfoobar"}), "foobarfoobarfoobar"], [LogStash::Event.new({"message" => "dd2"}), "dd2"]]
      actual_events = subject.batch_http_events(input_events, 10, 3)
      expect(actual_events.length).to eq(3)
      expect(actual_events[0][0]).to eq("dd1")
      expect(actual_events[1][0]).to eq("...TRUNCATED...")
      expect(actual_events[2][0]).to eq("dd2")
    end
  end

  context "when facing HTTP connection issues" do
    [true, false].each do |force_v1_routes|
        it "should retry when server is returning 5XX " + (force_v1_routes ? "using v1 routes" : "using v2 routes") do
          api_key = 'XXX'
          stub_dd_request_with_return_code(api_key, 500, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should not retry when server is returning 4XX" do
          api_key = 'XXX'
          stub_dd_request_with_return_code(api_key, 400, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to_not raise_error
        end

        it "should retry when server is returning 429" do
          api_key = 'XXX'
          stub_dd_request_with_return_code(api_key, 429, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should retry when facing a timeout exception from manticore" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, Manticore::Timeout, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should retry when facing a socket exception from manticore" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, Manticore::SocketException, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should retry when facing a client protocol exception from manticore" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, Manticore::ClientProtocolException, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should retry when facing a dns failure from manticore" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, Manticore::ResolutionFailure, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should retry when facing a socket timeout from manticore" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, Manticore::SocketTimeout, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(LogStash::Outputs::DatadogLogs::RetryableError)
        end

        it "should not retry when facing any other general error" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, StandardError, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send(payload) }.to raise_error(StandardError)
        end

        it "should not stop the forwarder when facing any client uncaught exception" do
          api_key = 'XXX'
          stub_dd_request_with_error(api_key, StandardError, force_v1_routes)
          payload = '{}'
          client = LogStash::Outputs::DatadogLogs::DatadogHTTPClient.new Logger.new(STDOUT), false, false, "datadog.com", 80, false, api_key, force_v1_routes
          expect { client.send_retries(payload, 2, 2) }.to_not raise_error
        end
    end
  end

  context "when using TCP" do
    it "should re-encode events" do
      input_event = "{message=dd}"
      encoded_event = subject.format_tcp_event(input_event, "xxx", 1000)
      expect(encoded_event).to eq("xxx " + input_event)
    end

    it "should truncate too long messages" do
      input_event = "{message=foobarfoobarfoobar}"
      encoded_event = subject.format_tcp_event(input_event, "xxx", 20)
      expect(encoded_event).to eq("xxx {...TRUNCATED...")
    end
  end

  def stub_dd_request_with_return_code(api_key, return_code, force_v1_routes)
    stub_dd_request(api_key, force_v1_routes).
        to_return(status: return_code, body: "", headers: {})
  end

  def stub_dd_request_with_error(api_key, error, force_v1_routes)
    stub_dd_request(api_key, force_v1_routes).
        to_raise(error)
  end

  def stub_dd_request(api_key, force_v1_routes)
    if force_v1_routes
        stub_request(:post, "http://datadog.com/v1/input/#{api_key}").
            with(
                body: "{}",
                headers: {
                    'Connection' => 'Keep-Alive',
                    'Content-Type' => 'application/json'
                })
    else
        stub_request(:post, "http://datadog.com/api/v2/logs").
            with(
                body: "{}",
                headers: {
                    'Connection' => 'Keep-Alive',
                    'Content-Type' => 'application/json',
                    'DD-API-KEY' => "#{api_key}",
                    'DD-EVP-ORIGIN' => 'logstash',
                    'DD-EVP-ORIGIN-VERSION' => DatadogLogStashPlugin::VERSION
                })
    end
end
