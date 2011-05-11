module KamIRC
  module Sparks
    class Part < Spark
      def self.register(bot)
        bot.register(self, Box::Privmsg(target: bot.nick, from: /manveru/, text: /^part\s+(?<channels>.*)/))
      end

      def call
        matches[:text][:channels].split.each do |channel|
          bot.say "PART #{channel} :Just testin..."
        end
      end
    end
  end
end
