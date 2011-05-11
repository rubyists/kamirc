require 'eventmachine'

module KamIRC
  require_relative 'kamirc/parser'
  require_relative 'kamirc/spark'
  require_relative 'kamirc/box'
  require_relative 'kamirc/options_dsl'

  class Bot < EM::P::LineAndTextProtocol
    def self.connect(options, &block)
      pass = {
        host: 'localhost',
        port: 6667,
        nick: 'manverbot',
        realname: "Manveru's Bot"
      }.merge(options)
      EM.connect(pass[:host], pass[:port], self, pass, &block)
    end

    attr_reader :options

    def initialize(options)
      @options = options
      @reconnect = true
      @parser = Message.new
      @register = {}

      super()
    end

    def nick; options[:nick] end
    def host; options[:host] end
    def port; options[:port] end
    def password; options[:password] end
    def realname; options[:realname] end

    def connection_completed
      say KamIRC::Box::Pass(password: password) if password
      say KamIRC::Box::Nick(nick: nick)
      say KamIRC::Box::User(nick: nick, flags: USER_INVISIBLE, reserved: '*', realname: realname)
    end

    def quit(reason = "")
      @reconnect = false
      say("QUIT :#{reason}")
    end

    def receive_line(line)
      puts "< #{line}"
      msg = @parser.parse(line)
      EM.defer{ dispatch(box(msg)) }
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
      puts "Lost connection to #{host}:#{port}"

      return unless @reconnect

      EM.add_timer(1){
        puts "Reconnect to #{host}:#{port}"
        reconnect(host, port)
      }
    end

    def dispatch(box)
      @register.each do |matcher, spark|
        next unless matches = matching_selectors(box, matcher)

        spark.call(self, box, matches)
      end
    end

    def box(msg)
      cmd = msg[:cmd].to_s

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
      raw = msg.respond_to?(:to_message) ? msg.to_message : msg
      puts "> #{raw}"
      send_data("#{raw}\r\n")
    end

    def register(spark, selectors)
      @register[selectors] = spark
    end

    def add(*spark)
      spark.each{|spark|
        case spark
        when String, Symbol
          require_relative "kamirc/spark/#{spark}"
          query = /^#{spark.to_s.tr('_', '')}$/i

          if found = Sparks.constants.grep(query).first
            Sparks.const_get(found).register(self)
          else
            warn "No module found for %p" % [spark]
          end
        else
          spark.register(self)
        end
      }
    end
  end
end
