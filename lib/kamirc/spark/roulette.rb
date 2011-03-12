module KamIRC
  module Sparks
    class Roulette < Spark
      def self.register(bot)
        bot.register self, Box::Privmsg(text: /^\.#{bot.nick}\s+roulette\s*/)
        bot.register self, Box::Privmsg(target: bot.nick, text: /^roulette\s*$/)
      end

      MAGAZINE = [true] + [false] * 5
      STATE = {}
      REASONS = [
        'You just shot yourself!',
        'Suicide is never the answer.',
        'If you wanted to leave, you could have just said so...',
        "Good thing these aren't real bullets...",
        "That's gotta hurt...",
      ]

      def call
        reload if magazine.empty?
        reply "*spin* ..."

        EM.add_timer 4 do
          if magazine.pop
            reply "*BANG*"
            magazine.clear
          else
            reply "-click-"
          end
        end
      end

      def reload
        reply "*reload* ..."
        magazine.concat(MAGAZINE.dup.shuffle)
      end

      def magazine
        STATE[target.to_s] ||= MAGAZINE.dup.shuffle
      end
    end
  end
end
