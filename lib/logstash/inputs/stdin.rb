# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "concurrent/atomics"
require "socket" # for Socket.gethostname

# Read events from standard input.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline codec.
class LogStash::Inputs::Stdin < LogStash::Inputs::Base
  config_name "stdin"

  default :codec, "line"

  READ_SIZE = 16384

  def register
    @host = Socket.gethostname
    fix_streaming_codecs
  end

  def run(queue)
    puts "The stdin plugin is now waiting for input:" if $stdin.tty?
    while !stop?
      if data = stdin_read
        @codec.decode(data) do |event|
          decorate(event)
          event.set("host", @host) if !event.include?("host")
          queue << event
        end
      end
    end
  end

  # When a configuration is using this plugin
  # We are defining a blocking pipeline which cannot be reloaded
  def self.reloadable?
    false
  end

  private

  def stop
    $stdin.close rescue nil
  end

  def stdin_read
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
end
