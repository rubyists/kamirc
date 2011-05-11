module KamIRC
  # PRIVMSG is used to send private messages between users, as well as to send
  # messages to channels. <target> is usually the nickname of the recipient
  # of the message, or a channel name.
  module Box
    class Privmsg < Struct.new(:from, :cmd, :target, :text)
      REGISTER['PRIVMSG'] = self

      def self.from_message(msg)
        if prefix = msg[:user]
          new(msg[:user].to_s, 'PRIVMSG', *msg[:params].map(&:to_s))
        else
          new(nil, 'PRIVMSG', *msg[:params].map(&:to_s))
        end
      end

      def to_message
        ":#{from} #{cmd} #{target} :#{text}"
      end
    end

    def self.Privmsg(hash = {})
      Privmsg.new.tap do |instance|
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
