# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Copyright 2017 Datadog, Inc.

require "logstash/devutils/rspec/spec_helper"
require "logstash/outputs/datadog_logs"

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

  context "when using HTTP" do
    it "should create one batch of one event" do
      input_events = [LogStash::Event.new({"message" => "dd"})]
      expect(subject.batch_events(input_events, 1).length).to eq(1)
    end

    it "should create two batches of one event each" do
      input_events = [LogStash::Event.new({"message" => "dd1"}), LogStash::Event.new({"message" => "dd2"})]
      actual_events = subject.batch_events(input_events, 1)
      expect(actual_events.length).to eq(2)
      expect(actual_events[0][0].get("message")).to eq("dd1")
      expect(actual_events[1][0].get("message")).to eq("dd2")
    end

    it "should not re-encode events" do
      input_event = "{message=dd}"
      encoded_event = subject.encode(input_event, true, "xxx")
      expect(encoded_event).to eq(input_event)
    end
  end

  context "when using TCP" do
    it "should re-encode events" do
      input_event = "{message=dd}"
      encoded_event = subject.encode(input_event, false, "xxx")
      expect(encoded_event).to eq("xxx " + input_event)
    end
  end
end