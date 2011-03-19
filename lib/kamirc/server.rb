module KamIRC
  class Server < EM::P::LineAndTextProtocol
    def self.connect(options, &block)
      EM.start_server(options.host, options.port, self, options, &block)
    end

    def initialize(options)
      @options = options
      @parser = Message.new
      @pass = @nick = @user = nil
      @connecting = true

      super()
    end

    def receive_line(line)
      msg = @parser.parse(line)
      p msg
      EM.defer{ dispatch(box(msg)) }
    rescue Parslet::ParseFailed => error
      p line
      puts error, @parser.root.error_tree
    rescue Exception => ex
      p line
      puts ex, *ex.backtrace
    end

    def dispatch(box)
      p box

      case box.cmd.to_s.downcase
      when 'pass'
        @pass = box.params.first
      when 'nick'
        @nick = box.nick
      when 'user'
        @user = box.name
      when 'pong'
        if @ping_timeout_timer
          EM.cancel_timer(@ping_timeout_timer)
          @ping_timeout_timer = nil
        end
      end

      post_dispatch
    rescue Exception => ex
      puts ex, *ex.backtrace
    end

    def post_dispatch
      return unless @connecting && @nick && @user
      @connecting = false

      setup_ping

      say Box::Reply(
        from: {hostname: @options.host},
        target: @nick,
        cmd: '001',
        params: ["Welcome to KamIRC"]
      )
    end

    def setup_ping
      @ping_timer = EM.add_periodic_timer(60){
        @ping_timeout_timer = EM.add_timer(50){
          close_connection
        }

        say Box::Ping(server: @options.host)
      }
    end

    def box(msg)
      cmd = msg[:cmd].to_s

      if container = Box::REGISTER[cmd]
        container.from_message(msg)
      elsif cmd =~ /\d\d\d/
        Box::Reply.from_message(msg)
      else
        msg
      end
    end

    def say(msg)
      msg = msg.to_message if msg.respond_to?(:to_message)
      p say: msg
      send_data("#{msg}\r\n")
    end

    def ping
      say "PING"
    end
  end
end
