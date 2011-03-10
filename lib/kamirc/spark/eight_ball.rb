module KamIRC
  module Sparks
    # Modeled after https://secure.wikimedia.org/wikipedia/en/wiki/Magic_8-Ball
    class EightBall < Spark
      def self.register(bot)
        bot.register self, Box::Privmsg(text: /^\.8ball\s+\S/)
        bot.register self, Box::Privmsg(target: bot.nick, text: /^8ball\s+\S/)
      end

      ANSWERS = [
        "As I see it, yes", "It is certain", "It is decidedly so", "Most likely",
        "Outlook good", "Signs point to yes", "Without a doubt", "Yes",
        "Yes - definitely", "You may rely on it",

        "Reply hazy, try again", "Ask again later", "Better not tell you now",
        "Cannot predict now", "Concentrate and ask again",

        "Don't count on it", "My reply is no", "My sources say no",
        "Outlook not so good", "Very doubtful",
      ]

      def call
        reply(ANSWERS.sample)
      end
    end
  end
end
