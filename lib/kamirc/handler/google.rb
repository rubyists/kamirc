require 'json'
require 'open-uri'

module KamIRC
  class Google < Handler
    def self.register(bot)
      bot.register(self, Box::Privmsg(text: /^.google\s+(?<terms>.+)/))
    end

    def call
      target = msg.target == bot.nick ? msg.from_nick : msg.target

      bot.privmsg(msg.from_nick, google(matches[:text][:terms]))
    end

    def options
      bot.options.google_search
    end

    def google(terms)
      p options
      key = options.key
      cx = options.cx
      query = url_escape(terms)
      url = "https://www.googleapis.com/customsearch/v1?key=#{key}&cx=#{cx}&q=#{query}"
      p url

      open url do |io|
        json = JSON.parse(io.read)
        result = json["items"].first
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
