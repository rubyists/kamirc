module KamIRC
  module Box
    class Reply < Struct.new(:from, :cmd, :target, :vars, :params, :format)
      def self.from_message(msg)
        prefix, cmd = msg[:prefix], msg[:cmd].to_i
        params = msg[:params].map(&:to_s)
        target, params = params[0], params[1..-1]
        format = REPLIES.fetch(cmd)

        new(prefix, cmd, target, nil, params, format)
      end

      def to_message
        cmd = "%03d" % self.cmd

        if vars
          rest = format % vars
          ":#{from[:hostname]} #{cmd} #{target} #{rest}"
        else
          ":#{from[:hostname]} #{cmd} #{target} #{[*params].compact.join(' ')}"
        end
      end
    end

    def self.Reply(hash = {})
      Reply.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
        instance.cmd = instance.cmd.to_i
        instance.format ||= REPLIES.fetch(instance.cmd)
      end
    end
  end
end

if $0 == __FILE__
  require 'open-uri'
  require 'nokogiri'

  open('lib/kamirc/box/reply_formats.rb', 'w+') do |rfio|
    open("http://www.irchelp.org/irchelp/rfc/chapter6.html") do |htmlio|
      html = Nokogiri::HTML(htmlio)
      rfio.puts(<<-RUBY)
module KamIRC
  # This crazy hack provides names for reply numerics and their format.
  # The format relies on String.%(Hash) in 1.9, which is good for one-way
  # substitution.
  # There is no (feasable) way to get the reverse, as servers may differ on the
  # messages and the substituted values can be just about anything.
  #
  # There are other issues, like duplicate or invalid naming of substitute
  # keys, will just have to write a metric ton of specs to fix that.
  REPLIES = {
    # The server sends Replies 001 to 004 to a user upon successful
    # registration.
    (RPL_WELCOME = 1) => ":Welcome to the Internet Relay Network %{nick}!%{user}@%{host}",
    (RPL_YOURHOST = 2) => ":Your host is %{servername}, running version %{version}",
    (RPL_CREATED = 3) => ":This server was created %{date}",
    (RPL_MYINFO = 4) => "%{servername} %{version} %{available_user_modes} %{available_channel_modes}",

    (RPL_ISUPPORT = 5) => "%{support}",

    # Sent by the server to a user to suggest an alternative server.  This
    # is often used when the connection is refused because the server is
    # already full.
    # RFC 2812 defines this as 005, but
    # http://www.irc.org/tech_docs/draft-brocklesby-irc-isupport-03.txt
    # redefines it as RPL_ISUPPORT, which is much more widely used.
    # The draft also mentions that 010 is the new numeric for RPL_BOUNCE
    (RPL_BOUNCE = 10) => "Try server %{server_name}, port %{port_number}",
      RUBY
      code = nil
      html.css('dl > *').each do |child|
        case child.name
        when 'dt'
          code = child.text.strip
        when 'dd'
          childs = child.children
          name, format, desc = [childs.first, child.css('i'), childs.last].map(&:text)
          format.gsub!(/^"([^"]+)"$/, '\1')

          case format
          when ":There are <integer> users and <integer> invisible on <integer> servers"
            format.replace(":There are %{users} users and %{invisible} invisible on %{servers} servers")
          when "<integer> :operator(s) online"
            format.replace("%{operators} :operator(s) online")
          when "<integer> :unknown connection(s)"
            format.replace("%{unknown} :unknown connection(s)")
          when "<integer> :channels formed"
            format.replace("%{channels} :channels formed")
          when ":I have <integer> clients and <integer> servers"
            format.replace(":I have %{clients} clients and %{servers} servers")
          else
            format.gsub!(/<nickname>/, "<nick>")
            format.gsub!(/<([^>]+)>/){ '%{' + $1.tr(' ', '_') + '}' }
          end

          desc.gsub!(/\s+/, ' ')
          desc.strip!
          rfio.puts "    # #{desc[2..-1]}" if desc.start_with?('-')
          rfio.puts "    (%s = %d) => %p," % [name, code, format]
        end
      end

      rfio.puts(<<-RUBY)
  }
end
      RUBY
    end
  end
else
  require_relative 'reply_formats'
end
