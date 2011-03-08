require 'eventmachine'

module KamIRC
  require_relative 'kamirc/parser'
  require_relative 'kamirc/handler'
  require_relative 'kamirc/box'
  require_relative 'kamirc/options_dsl'

  class Bot < EM::P::LineAndTextProtocol
    def self.connect(options, &block)
      EM.connect(options.host, options.port, self, options, &block)
    end

    attr_reader :options

    def initialize(options)
      @options = options
      @parser = Message.new
      @register = {}

      super()
    end

    def nick
      options.nick
    end

    def connection_completed
      say("PASS #{options.pass}") if options.pass
      say("NICK #{options.nick}")
      say("USER #{options.nick} 0 * :#{options.user}")
    end

    def receive_line(line)
      dispatch(@parser.parse(line))
    rescue Parslet::ParseFailed => error
      p line
      puts error, @parser.root.error_tree
    rescue Exception => ex
      p line
      puts ex, *ex.backtrace
    end

    def receive_error(error)
      p error: error
    end

    def unbind
      host, port = options.host, options.port
      puts "Lost connection to #{host}:#{port}"

      EM.add_timer(1){
        puts "Reconnect to #{host}:#{port}"
        reconnect(host, port)
      }
    end

    def dispatch(msg)
      box = box(msg)
      p box

      @register.each do |matcher, handler|
        next unless matches = matching_selectors(box, matcher)

        handler.call(self, box, matches)
      end
    end

    def box(msg)
      cmd = msg[:cmd]

      unless container = Box::REGISTER[cmd]
        if cmd =~ /\d\d\d/
          container = Box::Reply
        else
          return msg
        end
      end

      container.from_message(msg)
    end

    def matching_selectors(box, matcher)
      return unless matcher.kind_of?(box.class)

      matches = {}

      all = matcher.members.all?{|member|
        next true unless value = matcher[member]

        if value.is_a?(Regexp)
          if md = value.match(box[member])
            matches[member] = md
          end
        else
          matches[member] = value === box[member]
        end
      }

      matches if all
    end

    def privmsg(to, text)
      say("PRIVMSG #{to} :#{text}")
    end

    def say(msg)
      p say: msg
      send_data("#{msg}\r\n")
    end

    def register(handler, selectors)
      @register[selectors] = handler
    end

    def add(*handlers)
      handlers.each{|handler| handler.register(self) }
    end
  end
end
