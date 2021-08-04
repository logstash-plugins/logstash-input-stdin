# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/plugin_mixins/ecs_compatibility_support/spec_helper'
require "logstash/inputs/stdin"

describe LogStash::Inputs::Stdin do
  context ".reloadable?" do
    subject { described_class }

    it "returns true" do
      expect(subject.reloadable?).to be_falsey
    end
  end

  context "codec (PR #1372)" do
    it "switches from plain to line" do
      require "logstash/codecs/plain"
      require "logstash/codecs/line"
      plugin = LogStash::Inputs::Stdin.new("codec" => LogStash::Codecs::Plain.new)
      plugin.register
      expect( plugin.codec ).is_a?(LogStash::Codecs::Line)
    end

    it "switches from json to json_lines" do
      require "logstash/codecs/json"
      require "logstash/codecs/json_lines"
      plugin = LogStash::Inputs::Stdin.new("codec" => LogStash::Codecs::JSON.new)
      plugin.register
      expect( plugin.codec ).is_a?(LogStash::Codecs::JSONLines)
    end
  end

  context 'ECS behavior', :ecs_compatibility_support do

    subject { LogStash::Inputs::Stdin.new }

    ecs_compatibility_matrix(:v1, :v8 => :v1) do

      before(:each) do
        allow_any_instance_of(described_class).to receive(:ecs_compatibility).and_return(ecs_compatibility)

        subject.register

        subject.send :process, stdin_data, queue

        expect( queue.size ).to eql 1
      end

      let(:queue) { Queue.new }

      let(:stdin_data) { "a foo bar\n" }

      after { subject.close }

      it "sets message" do
        event = queue.pop
        expect( event.get('message') ).to eql 'a foo bar'
      end

      it "sets hostname" do
        event = queue.pop
        expect( event.get('host') ).to eql 'hostname' => `hostname`.strip
      end

      it "sets event.original" do
        event = queue.pop
        expect( event.get('event') ).to eql 'original' => stdin_data
      end

    end
  end

  context 'ECS disabled' do

    subject { LogStash::Inputs::Stdin.new('ecs_compatibility' => 'disabled') }

    before(:each) do
      subject.register

      subject.send :process, stdin_data, queue

      expect( queue.size ).to eql 1
    end

    let(:queue) { Queue.new }

    let(:stdin_data) { "a bar foo\n" }

    after { subject.close }

    it "sets message" do
      event = queue.pop
      expect( event.get('message') ).to eql 'a bar foo'
    end

    it "sets hostname" do
      event = queue.pop
      expect( event.get('host') ).to eql `hostname`.strip
    end

  end
end
