# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "concurrent/atomics"
require 'logstash/plugin_mixins/ecs_compatibility_support'
require "socket" # for Socket.gethostname
require "jruby-stdin-channel"

# Read events from standard input.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline codec.
class LogStash::Inputs::Stdin < LogStash::Inputs::Base
  include LogStash::PluginMixins::ECSCompatibilitySupport(:disabled, :v1)

  config_name "stdin"

  default :codec, "line"

  READ_SIZE = 16384

  def initialize(*params)
    super

    @host_key = ecs_select[disabled: 'host', v1: '[host][hostname]']
  end

  def register
    begin
      @stdin = StdinChannel::Reader.new
      self.class.module_exec { alias_method :stdin_read, :channel_read }
      self.class.module_exec { alias_method :stop, :channel_stop}
    rescue => e
      @logger.debug("fallback to reading from regular $stdin", :exception => e)
      self.class.module_exec { alias_method :stdin_read, :default_read }
      self.class.module_exec { alias_method :stop, :default_stop }
    end

    @host = Socket.gethostname
    fix_streaming_codecs
  end

  def run(queue)
    puts "The stdin plugin is now waiting for input:" if $stdin.tty?
    while !stop?
      if data = stdin_read
        process(data, queue)
      end
    end
  end

  # When a configuration is using this plugin
  # We are defining a blocking pipeline which cannot be reloaded
  def self.reloadable?
    false
  end

  private

  def process(data, queue)
    @codec.decode(data) do |event|
      decorate(event)
      event.set(@host_key, @host) if !event.include?(@host_key)
      queue << event
    end
  end

  def default_stop
    $stdin.close rescue nil
  end

  def channel_stop
    @stdin.close rescue nil
  end

  def default_read
    begin
      return $stdin.sysread(READ_SIZE)
    rescue IOError, EOFError
      do_stop
    rescue => e
      # ignore any exception in the shutdown process
      raise(e) unless stop?
    end
    nil
  end

  def channel_read
    begin
      return @stdin.read(READ_SIZE)
    rescue IOError, EOFError, StdinChannel::ClosedChannelError
      do_stop
    rescue => e
      # ignore any exception in the shutdown process
      raise(e) unless stop?
    end
    nil
  end
end
