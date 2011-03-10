require 'em-http-request'
require 'nokogiri'

module KamIRC
  module Sparks
    class Pun < Spark
      def self.register(bot)
        bot.register self, Box::Privmsg(text: /^\.pun\s*$/)
        bot.register self, Box::Privmsg(target: bot.nick, text: /^pun\s*$/)
      end

      def call
        conn = EM::HttpRequest.new('http://www.punoftheday.com/cgi-bin/randompun.pl')
        req = conn.get
        req.callback do
          doc = Nokogiri::HTML(req.response)
          pun = doc.at('#main-content p').text
          reply pun
        end
      end
    end
  end
end
