require 'time'
require 'socket'
require 'ipaddr'
require 'set'

module KamIRC
  class Server < EM::P::LineAndTextProtocol
    # A channel is a named group of one or more users which will all receive
    # messages addressed to that channel. A channel is characterized by its
    # name, properties and current members.
    #
    # Channels names are strings (beginning with a '&', '#', '+' or '!'
    # character) of length up to fifty (50) characters. Channel names are case
    # insensitive.
    #
    # Apart from the the requirement that the first character being either '&',
    # '#', '+' or '!' (hereafter called "channel prefix").
    #
    # The only restriction on a channel name is that it SHALL NOT contain any
    # spaces (' '), a control G (^G or ASCII 7), a comma (',' which is used as
    # a list item separator by the protocol).
    #
    # Also, a colon (':') is used as a delimiter for the channel mask. The
    # exact syntax of a channel name is defined in "IRC Server Protocol"
    # [IRC-SERVER].
    class Channel < Struct.new(:name, :topic, :channel, :users, :subscriptions, :modes)
      # Oh, the wonderful world of channel modes...
      #
      # a - toggle the anonymous channel flag;
      # i - toggle the invite-only channel flag;
      # m - toggle the moderated channel;
      # n - toggle the no messages to channel from clients on the
      #     outside;
      # q - toggle the quiet channel flag;
      # p - toggle the private channel flag;
      # s - toggle the secret channel flag;
      # r - toggle the server reop channel flag;
      # t - toggle the topic settable by channel operator only flag;

      # k - set/remove the channel key (password);
      # l - set/remove the user limit to channel;

      # b - set/remove ban mask to keep users out;
      # e - set/remove an exception mask to override a ban mask;
      # I - set/remove an invitation mask to automatically override
      #     the invite-only flag;

      def initialize(name, topic = nil)
        self.channel = EM::Channel.new
        self.users = Set.new
        self.subscriptions = {}
        self.modes = {}

        self.name, self.topic = name, topic
      end

      def <<(box)
        channel << box
      end

      def join(user)
        return if users.include?(user)
        users << user

        subscriptions[user] = channel.subscribe{|box|
          case box.cmd
          when 'PRIVMSG'
            user.say(box) unless box.from_nick == user.nick
          else
            user.say(box)
          end
        }

        yield(self) if block_given?

        channel << Box::Join(target: user.prefix, channel: name)
      end

      def part(user)
        return unless users.include?(user)
        channel << Box::Part(target: user.prefix, channel: name)
        users.delete(user)
        channel.unsubscribe(subscriptions.delete(user))
      end

      def topic=(topic)
        self[:topic] = topic
      end
    end

    def self.connect(options, &block)
      EM.start_server(options.host, options.port, self, options, &block)
    end

    attr_reader :nick, :user, :host

    USERS = {}
    CHANNELS = {}

    def initialize(options)
      @options = options
      @parser = Message.new
      @pass = @nick = @user = nil
      @connecting = true

      super()
    end

    def receive_line(line)
      puts "> %p" % [line]
      msg = @parser.parse(line)
      EM.defer{ dispatch(box(msg)) }
    rescue Parslet::ParseFailed => error
      p line
      puts error, @parser.root.error_tree
    rescue Exception => ex
      p line
      puts ex, *ex.backtrace
    end

    def prefix
      "#{nick}!#{nick}@#{host}"
    end

    attr_reader :nick

    def dispatch(box)
      method = "dispatch_#{box.cmd.to_s.downcase}"

      if respond_to?(method)
        send(method, box)
      else
        p no_dispatch: box
      end

      post_dispatch
    rescue Exception => ex
      puts ex, *ex.backtrace
    end

    def post_dispatch
      return unless @connecting && @nick && @user
      @connecting = false

      setup_ping
      say_connect
    end

    def dispatch_mode(box)
      p mode: box

      if box.mode
      else
        case target = box.target
        when /^#/ # channel
          if channel = CHANNELS[target]
            channel.mode
            reply(RPL_CHANNELMODEIS, channel: channel, mode: channel.mode)
          end
        end
      end

      # {:mode=>#<struct KamIRC::Box::Mode from=nil, cmd="MODE", target="#foo", mode=nil>}

      # 09:29 znc --> | :calvino.freenode.net 324 manveru #ramaze +cjnt 3:45
      # 09:29 znc --> | :calvino.freenode.net 329 manveru #ramaze 1170729411
    end

    # {:cmd=>"PRIVMSG"@0, :params=>["#foo"@8, "hello"@14]}
    def dispatch_privmsg(box)
      case box.target
      when /^#/ # to channel
        if channel = CHANNELS[box.target]
          box.from_nick = @nick
          box.from_user = @nick
          box.from_host = @options.host
          channel << box
        end
      else # to client
        if client = USERS[box.target]
          box.from_nick = @nick
          box.from_user = @nick
          box.from_host = @options.host
          client.say(box)
        end
      end
    end

    def dispatch_topic(box)
      if channel = CHANNELS[box.channel]
        if topic = box.text
          channel.topic = topic
          reply(RPL_TOPIC, channel: channel.name, topic: channel.topic)
        else
          reply(RPL_TOPIC, channel: channel.name, topic: channel.topic)
        end
      else
        reply(RPL_NOTOPIC, channel: channel.name)
      end
    end

    def dispatch_pass(box)
      @pass = box.params.first
    end

    def dispatch_join(box)
      name = box.channel
      channel = CHANNELS[name] ||= Channel.new(name)
      channel.join self do
        say Box::Join(target: prefix, channel: channel.name)

        if channel.topic
          reply(RPL_TOPIC, channel: channel.name, topic: channel.topic)
        else
          reply(RPL_NOTOPIC, channel: channel.name)
        end

        nicks = %w[a bc def ghijk lmnopq rstuvwx @yz].join(' ')
        reply(RPL_NAMREPLY, visibility: '@', channel: channel.name, nicks: nicks)
        reply(RPL_ENDOFNAMES, channel: channel.name)

        say ":#{prefix} MODE #{channel.name} +v #{@nick}"
      end
    end

    def dispatch_part(box)
      channel = CHANNELS[box.channel]
      channel.part(self) if channel
    end

    def dispatch_quit(box)
      # answer to channels and the user
      # :madveru!~madveru@EM114-48-215-204.pool.e-mobile.ne.jp QUIT :Client Quit
      say Box::Quit(target: prefix, message: box.message)
      close_connection_after_writing
    end

    def dispatch_nick(box)
      nick = box.nick

      if USERS.key?(nick)
        say_nickname_is_already_in_use
      else
        @nick = nick
        USERS[@nick] = self
      end
    end

    def dispatch_user(box)
      @user = box.realname
    end

    def dispatch_ping(box)
      say Box::Pong(server: box.server)
    end

    def dispatch_pong(box)
      if @ping_timeout_timer
        EM.cancel_timer(@ping_timeout_timer)
        @ping_timeout_timer = nil
      end
    end

    def say_rpl_notopic(channel)
      reply cmd: '331', params: [channel, "No topic is set"]
    end

    def say_connect
      @port, @ip = Socket.unpack_sockaddr_in(get_peername)
      @host = Socket.gethostbyaddr(IPAddr.new(@ip).hton).first

      reply(RPL_WELCOME, nick: nick, user: nick, host: host)
      reply(RPL_YOURHOST, servername: @options.host, version: @options.version)
      reply(RPL_CREATED, date: @options.creation_time.strftime('%a %b %d %Y at %T %Z'))
      reply(RPL_MYINFO, servername: @options.host, version: @options.version,
            available_user_modes: @options.available_user_modes,
            available_channel_modes: @options.available_channel_modes)
      say_lusers
      say_motd
    end

    def say_motd
      if path = @options.motd_path
        File.open @options.motd_path do |motd|
          reply(RPL_MOTDSTART, server: @options.host)
          motd.each_line do |line|
            reply(RPL_MOTD, text: line.chomp)
          end
          reply(RPL_ENDOFMOTD)
        end
      else
        reply(ERR_NOMOTD)
      end
    end

    # Message server sends you when you connect.
    #
    # :Welcome to the Internet Relay Network, <nick>
    #
    # :Welcome to the Internet Relay Network, Dana
    def say_connect_message
    end

    # Information line on connect.
    #
    # :Your host is <server-name>, running version <ircd-version>
    #
    # :jordan.freenode.net 002 madverbot :Your host is jordan.freenode.net[213.161.196.11/6667], running version ircd-seven-1.0.3
    def say_connect_information
      reply cmd: '002', params: [
        "Your host is #{@options.host}[#{@options.ip}/#{@options.port}] running version KamIRC-0"
      ]
    end

    # :jordan.freenode.net 003 madverbot :This server was created Wed Feb 24 2010 at 00:03:08 CET
    # most servers seem to use this format
    def say_connect_server_creation_time
      time = @creation_time.strftime('%a %b %d %Y at %T %Z')
      reply cmd: '003', params: ["This server was created #{time}"]
    end

    # :jordan.freenode.net 004 madverbot jordan.freenode.net ircd-seven-1.0.3 DOQRSZaghilopswz CFILMPQbcefgijklmnopqrstvz bkloveqjfI
    # <server> <version> <usermodes> <channelmodes> [<channelmodes requireing an add-argument>]
    #
    # NOTE: find out what the hell that is all about.
    def say_connect_server_information
      info = [@options.host, @options.version, @options.channelmodes]
      reply cmd: '004', params: [info.join(' ')]
    end

    # Detailed server restrictions, modes ect.
    # <protocol|setting> [<protocol|setting> ...] :are available on this server
    #
    # :jordan.freenode.net 005 madverbot
    #   CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFLMPQcgimnprstz
    #   CHANLIMIT=#:120 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=freenode
    #   KNOCK STATUSMSG=@+ CALLERID=g :are supported by this server
    # :jordan.freenode.net 005 madverbot
    #   SAFELIST ELIST=U CASEMAPPING=rfc1459 CHARSET=ascii NICKLEN=16
    #   CHANNELLEN=50 TOPICLEN=390 ETRACE CPRIVMSG CNOTICE DEAF=D MONITOR=100
    #   :are supported by this server
    # :jordan.freenode.net 005 madverbot
    #   FNC
    #   TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR:
    #   EXTBAN=$,arx WHOX CLIENTVER=3.0 :are supported by this server
    #
    # @todo implement reply
    def say_connect_server_restrictions
      info = {
        callerid:    'g',
        casemapping: 'rfc1459',
        chanlimit:   '#:120',
        chanmodes:   'eIbq,k,flj,CFLMPQcgimnprstz',
        channellen:  50,
        chantypes:   '#',
        charset:     'ascii',
        clientver:   3.0,
        cnotice:     true,
        cprivmsg:    true,
        deaf:        'D',
        elist:       'U',
        etrace:      true,
        excepts:     true,
        extban:      '$,arx',
        fnc:         true,
        invex:       true,
        knock:       true,
        maxlist:     'bqeI:100',
        modes:       4,
        monitor:     100,
        network:     'freenode',
        nicklen:     16,
        prefix:      '(ov)@+',
        safelist:    true,
        statusmsg:   '@+',
        targmax:     'NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR:',
        topiclen:    390,
        whox:        true,
      }
    end

    def say_lusers
      say_lusers_connect
      say_lusers_operators
      say_lusers_unknown
      say_lusers_channels
      say_lusers_connections
      say_lusers_local_users_and_max
      say_lusers_global_users_and_max
      say_lusers_highest_connection_count
    end

    # These numbers are for the entire network, not just one server. Adding the
    # first two numbers together will give you the current total user count on
    # the entire network.
    #
    # :There are <user> users and <invis> invisible on <serv> servers
    #
    # :jordan.freenode.net 251 madverbot :There are 366 users and 58854 invisible on 26 servers
    def say_lusers_connect
      reply RPL_LUSERCLIENT, users: 1, invisible: 1, servers: 1
    end

    # These numbers are for the entire network, not just one server. Note that
    # if a network has no operators online, this will not be sent.
    #
    # <num> :operator(s) online
    #
    # :jordan.freenode.net 252 madverbot 34 :IRC Operators online
    def say_lusers_operators
      reply RPL_LUSEROP, operators: 1
    end

    # The number of unknown connections
    #
    # <num> :unknown connection(s)
    #
    # :jordan.freenode.net 253 madverbot 13 :unknown connection(s)
    def say_lusers_unknown
      reply RPL_LUSERUNKNOWN, unknown: 1
    end

    # The number of channels currently formed
    #
    # <num> :channels formed
    #
    # :jordan.freenode.net 254 madverbot 36948 :channels formed
    def say_lusers_channels
      reply RPL_LUSERCHANNELS, channels: CHANNELS.size
    end

    # These numbers are for the current server only. Note that the server count
    # does not include the current server, it is a count of all OTHER servers
    # connected to it.
    #
    # :I have <user> clients and <serv> servers
    #
    # :jordan.freenode.net 255 madverbot :I have 4330 clients and 1 servers
    def say_lusers_connections
      reply RPL_LUSERME, clients: 1, servers: 1
    end

    # These numbers are just for the current server. The maximum count
    # signifies the highest count of users the server has had at any time since
    # it was last rebooted.
    #
    # :Current local users: <curr> Max: <max>
    #
    # :jordan.freenode.net 265 madverbot 4330 8465 :Current local users 4330, max 8465
    #
    # TODO: not part of the RFC, no format for it
    def say_lusers_local_users_and_max
      # reply 265, users: 1, max: 1
    end

    # These numbers are for the entire network.The maximum count signifies the
    # highest count of users that the entire NETWORK has had at any time since
    # the SERVER was last rebooted.
    #
    # :Current global users: <curr> Max: <max>
    #
    # :jordan.freenode.net 266 madverbot 59220 74011 :Current global users 59220, max 74011
    #
    # TODO: not part of the RFC, no format for it
    def say_lusers_global_users_and_max
      # reply 265, users: 1, max: 1
    end

    # Returned for a STATS u request. Also returned on some networks during the
    # connection process. These numbers signify the highest count the server
    # has had at any time since it was last rebooted.
    #
    # :Highest connection count: <total> (<num> clients)
    #
    # :jordan.freenode.net 250 madverbot :Highest connection count: 8466 (8465
    # clients) (1229899 connections received)
    #
    # TODO: not part of the RFC, no format for it
    def say_lusers_highest_connection_count
      # reply 250, total: 1, clients: 1
    end

    # Server Up 32 days, 21:17:36
    # Highest connection count: 8127 (8123 clients) (366417 connections received)
    # u :End of /STATS report
    def say_stats_u
    end

    # This is sent in reply to a MOTD request or on connection, immediately
    # preceding the text for the actual message of the day.
    #
    # :- <server> Message of the Day -
    #
    # :jordan.freenode.net 375 madverbot :- jordan.freenode.net Message of the Day -
    def say_motd_intro
      reply cmd: '375', params: ["- <server> Message of the Day -"]
    end

    # This is sent in reply to a MOTD request or on connection. In most cases,
    # multiple replies will be sent, one for each line in the MOTD.
    #
    # :- <info>
    #
    # :jordan.freenode.net 372 madverbot :- Welcome to jordan.freenode.net in Evry, FR, EU.
    def say_motd_body
      reply cmd: '265', params: ["- Welcome to KamIRC"]
    end

    # Returned when trying to change your nickname to a nickname that someone else is using.
    def say_nickname_is_already_in_use
      reply cmd: '433', params: ['Nickname is already in use.']
    end

    # 332	topic,join
    # Format:	<channel> :<topic>
    # Info:	This is returned for a TOPIC request or when you JOIN, if the channel has a topic.
    # Example:	#help.script :| QuakeNet is such a great place to be. | Don't privmsg staff! |
    def say_join_topic(channel, topic)
      reply cmd: '332', params: [topic] if topic
    end

    # 333	topic,join
    # Format:	<channel> <nickname> <time>
    # Info:	This is returned for a TOPIC request or when you JOIN, if the channel has a topic. <time> is in ctime format. (Represents time topic was set.)
    # Example:	#help.script Q 902508764
    def say_join_time(channel)
      reply cmd: '333', params: [
        channel, @nick, Time.now.to_i
      ]
    end

    # 353	names,join
    # Format:	<*|@|=> <channel> :<names>
    # Info:	This is returned for a NAMES request for a channel, or when you initially join a channel. It contains a list of every user on the channel. If channel mode p, returns *. If channel mode s, returns @. If neither, returns =.
    # Example:	= #help.script :@Dana @Q +SomeHelper +AsecondHelper cow god
    #
    # 366	names,join
    # Format:	<channel> :End of /NAMES list.
    # Info:	This is returned at the end of a NAMES list, after all visible names are returned.
    # Example:	#help.script :End of /NAMES list.
    def say_join_names(channel)
      reply cmd: '353', params: ['=', channel, '']
      reply cmd: '366', params: [channel, 'End of /NAMES list']
    end

    # 405	join
    # Format:	<channel> :You have joined too many channels
    # Info:	Returned if you try to JOIN a channel and you have already reached the maximum number of channels for that server. You will not be able to JOIN any more channels until you PART some of your current channels.
    # Example:	#help.script :You have joined too many channels
    def say_too_many_channels
    end

    # 439	notice,privmsg,join
    # Format:	<target> :Target change too fast. Please wait <sec> seconds.
    # Info:	This is used on some networks as a way to prevent spammers and other mass-messagers. This is returned when a user tries to message too many different users or join too many different channels in a short period of time.
    # Example:	Dana :Target change too fast. Please wait 104 seconds.
    def say_target_change_too_fast
    end

    # 471	join
    # Format:	<channel> :Cannot join channel (+l)
    # Info:	Returned when attempting to JOIN a channel that has already reached it's user limit. A channel can set a user limit by setting a MODE +l with a maximum number of users. Once that many users are in the channel, any other users attempting to JOIN will get this reply.
    # Example:	#help.script :Cannot join channel (+l)
    def say_cannot_join_too_many_users
    end

    # 473	join
    # Format:	<channel> :Cannot join channel (+i)
    # Info:	Returned when attempting to JOIN a channel that is INVITE-only (MODE +i) without being invited. A channel is invite-only if a channel op sets a MODE +i. Only a channel op can INVITE a user to an invite-only channel.
    # Example:	#help.script :Cannot join channel (+i)
    def say_cannot_join_invite_only
    end

    # 474	join
    # Format:	<channel> :Cannot join channel (+b)
    # Info:	Returned when attempting to JOIN a channel that you are banned from.
    # Example:	#help.script :Cannot join channel (+b)
    def say_cannot_join_banned
    end

    # 475	join
    # Format:	<channel> :Cannot join channel (+k)
    # Info:	Returned when attempting to JOIN a channel that has a key set (MODE +k) when you have not used the proper key.
    # Example:	#help.script :Cannot join channel (+k)
    def say_cannot_join_key
    end

    # 477	join
    # Format:	<channel> :Cannot join channel (+r)
    # Info:	This is returned if you try to join a channel with +r while you aren't authed.
    # Example:	#help.script :Cannot join channel (+r)
    def say_cannot_join_auth
    end

    # 479	join
    # Format:	<channel> :Cannot join channel (access denied on this server)
    # Info:	This is returned if you try to join a channel which is glined.
    # Example:	#help.script :Cannot join channel (access denied on this server)
    def say_cannot_join_glined
    end

    # JOIN	join
    # Format:	JOIN :<channel>
    # Info:	Sent when someone joins a channel you're in
    # Example:	JOIN :#help.script
    def say_joined(channel)
      say Box::Join(cmd: 'JOIN', target: "#{@nick}!#{@user}@#{@host}", channel: channel)
    end

    def setup_ping
      @ping_timer = EM.add_periodic_timer(60){
        @ping_timeout_timer = EM.add_timer(50){
        # also say to all channels he's on?
        say ":#{nick}!#{nick}@#{host} QUIT :Timeout"
        close_connection_after_writing
      }
      say_ping
      }
    end

    def box(msg)
      cmd = msg[:cmd].to_s

      if container = Box::REGISTER[cmd]
        container.from_message(msg)
      elsif cmd =~ /\d\d\d/
        Box::Reply.from_message(msg)
      else
        p msg
        raise "No box found for #{cmd}"
      end
    rescue Exception => ex
      p msg
      puts ex, *ex.backtrace
    end

    def say(msg)
      msg = msg.to_message if msg.respond_to?(:to_message)
      puts "< %p" % [msg]
      send_data("#{msg}\r\n")
    end

    def reply(code, vars = {})
      default = {from: {hostname: @options.host}, target: @nick}
      say Box::Reply(default.merge(cmd: code, vars: vars))
    end

    # (manveru) CLI -> ZNC [PING tigershark.rubyists.com]
    # (manveru) ZNC -> CLI [:irc.znc.in PONG irc.znc.in tigershark.rubyists.com]
    def say_ping
      say Box::Ping(server: @options.host)
    end

    def unbind
      USERS.delete @nick
    end
  end
end
