module KamIRC
  module Sparks
    class Say < Spark
      def self.register(bot)
        bot.register(self, Box::Privmsg(target: bot.nick, from: /manveru/, text: /^say\s+(?<target>\S+)\s+(?<msg>.+)$/))
      end

      def call
        bot.privmsg(matches[:text][:target], matches[:text][:msg])
      end
    end
  end
end
