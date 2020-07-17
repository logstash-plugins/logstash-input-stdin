# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "insist"
require "socket"
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
      insist { plugin.codec }.is_a?(LogStash::Codecs::Line)
    end

    it "switches from json to json_lines" do
      require "logstash/codecs/json"
      require "logstash/codecs/json_lines"
      plugin = LogStash::Inputs::Stdin.new("codec" => LogStash::Codecs::JSON.new)
      plugin.register
      insist { plugin.codec }.is_a?(LogStash::Codecs::JSONLines)
    end
  end

  context "stdin close" do
    # this spec tests for the interruptibility of $stdin
    # for more context see https://github.com/logstash-plugins/logstash-input-stdin/pull/19
    # starting at JRuby 9.1.15.0 it is possible to interrupt $stdin.syscall with $stdin.close
    # this spec is here to prevent regression on this behaviour

    let(:signal) { Queue.new }

    it "should interrupt sysread" do

      # launch a $stdin.sysread operation is a separate thread
      # where the thread return value will be the sysread IOError
      # caused by the close call.
      sysread_thread = Thread.new do
        result = nil
        begin
          signal << "starting read"
          $stdin.sysread(1)
        rescue => e
          result = e
        end
        result
      end

      # wait for thread to be ready to call sysread
      signal.pop
      # wait jsut a bit more to make sure the sysread call is made
      sleep(0.5)

      # launch close in a separate thread because on Rubies which does not support interruptibility
      # close will block
      Thread.new do
        $stdin.close
      end

      Timeout.timeout(5) do
        expect(sysread_thread.value).to be_a(IOError)
        expect(sysread_thread.value.message).to match(/stream closed/)
      end
    end
  end

end
