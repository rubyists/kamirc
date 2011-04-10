module KamIRC
  # PRIVMSG is used to send private messages between users, as well as to send
  # messages to channels. <target> is usually the nickname of the recipient
  # of the message, or a channel name.
  module Box
    class Privmsg < Struct.new(:from_nick, :from_user, :from_host, :from, :cmd, :target, :text)
      REGISTER['PRIVMSG'] = self

      def self.from_message(msg)
        if prefix = msg[:prefix]
          new(
            prefix[:nickname],
            prefix[:user],
            prefix[:host],
            msg[:prefix],
            'PRIVMSG',
            *msg[:params]
          )
        else
          new(nil, nil, nil, nil, 'PRIVMSG', *msg[:params].map(&:to_s))
        end
      end

      def to_message
        ":#{from_nick}!#{from_user}@#{from_host} #{cmd} #{target} :#{text}"
      end
    end

    def self.Privmsg(hash = {})
      Privmsg.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
