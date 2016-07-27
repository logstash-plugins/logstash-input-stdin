# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "concurrent/atomics"
require "socket" # for Socket.gethostname

# Read events from standard input.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline filter.
class LogStash::Inputs::Stdin < LogStash::Inputs::Base
  config_name "stdin"

  default :codec, "line"

  def register
    @host = Socket.gethostname
    fix_streaming_codecs
  end

  def run(queue)
    while !stop?
      begin
        # Based on some testing, there is no way to interrupt an IO.sysread nor
        # IO.select call in JRuby. Bummer :(
        data = $stdin.sysread(16384)
        if @carry_over
          data = @carry_over + data
          @carry_over = nil
        end
        unless data =~ /\n\Z/
          lines = data.lines.to_a
          @carry_over = lines.pop
          data = lines.join("\n")
        end
        @codec.decode(data) do |event|
          decorate(event)
          event["host"] = @host if !event.include?("host")
          queue << event
        end
      rescue IOError, EOFError # stdin closed
        if @carry_over
          carry_over = @carry_over
          @carry_over = nil
          @codec.decode(carry_over) do |event|
            decorate(event)
            event["host"] = @host if !event.include?("host")
            queue << event
          end
        end
        break
      rescue => e
        # ignore any exception in the shutdown process
        break if stop?
        raise(e)
      end
    end
  end

  def stop
    $stdin.close rescue nil
  end
end
