# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "socket" # for Socket.gethostname

# Read events from standard input.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline filter.
class LogStash::Inputs::Stdin < LogStash::Inputs::Base
  config_name "stdin"

  default :codec, "line"

  public
  def register
    @host = Socket.gethostname
    fix_streaming_codecs
  end # def register

  def run(queue)
    while !stop?
      begin
        # Based on some testing, there is no way to interrupt an IO.sysread nor
        # IO.select call in JRuby. Bummer :(
        data = $stdin.sysread(16384)
        @codec.decode(data) do |event|
          decorate(event)
          event["host"] = @host if !event.include?("host")
          queue << event
        end
      rescue IOError, EOFError
        # stdin closed or a requested shutdown, just exit run
        break
      rescue
        raise unless stop?
        break
      end
    end
  end

  def stop
    super
    $stdin.close rescue nil
  end
end # class LogStash::Inputs::Stdin
