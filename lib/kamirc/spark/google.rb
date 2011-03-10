require 'json'
require 'open-uri'

module KamIRC
  module Sparks
    class Google < Spark
      def self.register(bot)
        bot.register(self, Box::Privmsg(text: /^.google\s+(?<terms>.+)/))
      end

      def call
        target = msg.target == bot.nick ? msg.from_nick : msg.target
        return unless result = google(matches[:text][:terms])
        bot.privmsg(target, result)
      end

      def options
        bot.options.google_search
      end

      def google(terms)
        key = options.key
        cx = options.cx
        query = url_escape(terms)
        url = "https://www.googleapis.com/customsearch/v1?key=#{key}&q=#{query}"

        p url

        open url do |io|
          json = JSON.parse(io.read)
          return unless result = json["items"].first
          title = result["title"]
          link = result["link"]

          return "#{title} -- #{link}"
        end
      end

      def url_escape(string)
        string.gsub(/([^ a-zA-Z0-9_.-]+)/u){
          "%#{$1.unpack('H2' * $1.bytesize).join('%').upcase}"
        }.tr(' ', '+')
      end
    end
  end
end
