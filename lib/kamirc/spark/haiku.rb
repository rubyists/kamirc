require 'em-http-request'
require 'nokogiri'

module KamIRC
  module Sparks
    class Haiku < Spark
      def self.register(bot)
        bot.register self, Box::Privmsg(text: /^\.haiku\s*$/)
        bot.register self, Box::Privmsg(target: bot.nick, text: /^haiku\s*$/)
      end

      def call
        conn = EM::HttpRequest.new("http://haikoo.org/explore/")
        req = conn.get
        req.callback do
          doc = Nokogiri::HTML(req.response)
          title = doc.css('.haikootitle').text
          verses = doc.css('.haikooline').map(&:text)
          reply "#{title}:  #{verses.join(' / ')}"
        end
      end
    end
  end
end
