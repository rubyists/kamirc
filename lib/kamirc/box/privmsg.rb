module KamIRC
  # PRIVMSG is used to send private messages between users, as well as to send
  # messages to channels. <target> is usually the nickname of the recipient
  # of the message, or a channel name.
  module Box
    class Privmsg < Struct.new(:from_nick, :from_user, :from_host, :from, :cmd, :target, :text)
      REGISTER['PRIVMSG'] = self

      def self.from_message(msg)
        prefix = msg[:prefix]

        new(
          prefix[:nickname],
          prefix[:user],
          prefix[:host],
          msg[:prefix],
          'PRIVMSG',
          *msg[:params]
        )
      end
    end

    def self.Privmsg(hash = {})
      Privmsg.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
