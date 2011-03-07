require 'parslet'

module KamIRC
  class MessageParser < Parslet::Parser
    # [ ":" prefix SPACE ] command [ params ] crlf
    rule :message do
      (str(':') >> prefix.as(:prefix) >> space).maybe >>
      command >>
      params.maybe.as(:params)
    end

    root :message

    # hostname / ( nickname [ [ "!" user ] "@" host ] )
    rule :prefix do
      prefix_user | prefix_server
    end

    rule :prefix_server do
      hostname.as(:hostname)
    end

    rule :prefix_user do
      # FIXME: This has precendence issues?
      # nickname.as(:nickname) >>
      # ((str('!') >> user.as(:user)).maybe >> str('@') >> host.as(:host)).maybe
      nickname.as(:nickname) >> str('!') >> user.as(:user) >> str('@') >> host.as(:host)
    end

    # 1*( %x01-09 / %x0B-0C / %x0E-1F / %x21-3F / %x41-FF )
    # ; any octet except NUL, CR, LF, " " and "@"
    rule :user do
      match('[^\0\r\n@ ]').repeat(1)
    end

    # 1*letter / 3digit
    rule :command do
      (letter.repeat(1) | digit.repeat(3, 3)).as(:cmd)
    end

    # *14( SPACE middle ) [ SPACE ":" trailing ] /
    #  14( SPACE middle ) [ SPACE [ ":" ] trailing ]
    rule :params do
      (
        (space >> middle.as(:param)).repeat(0, 14) >>
        (space >> str(':') >> trailing.as(:param)).maybe
      ) | (
        (space >> middle).repeat(14, 14) >>
        (space >> str(':').maybe >> trailing).maybe
      )
    end

    # %x01-09 / %x0B-0C / %x0E-1F / %x21-39 / %x3B-FF
    # any octet except NUL, CR, LF, " " and ":"
    rule :nospcrlfcl do
      match('[^\0\r\n: ]')
    end

    # nospcrlfcl *( ":" / nospcrlfcl )
    rule :middle do
      nospcrlfcl >> (str(':') | nospcrlfcl).repeat
    end

    # *( ":" / " " / nospcrlfcl )
    rule :trailing do
      (str(':') | str(' ') | nospcrlfcl).repeat
    end

    # %x20        ; space character
    rule :space do
      str(' ')
    end

    # %x0D %x0A   ; "carriage return" "linefeed"
    rule :crlf do
      str('\r\n')
    end

    # nickname / server
    rule :target do
      nickname | server
    end

    # msgto *( "," msgto )
    rule :msgtarget do
      msgto >> (str(',') >> msgto).repeat
    end

    # channel /
    # ( user [ "%" host ] "@" hostname ) /
    # ( user "%" host ) /
    # targetmask /
    # nickname /
    # ( nickname "!" user "@" host )
    rule :msgto do
      channel |
      (user >> (str('%') >> host).maybe >> str('@') >> hostname) |
      (user >> str('%') >> host) |
      targetmask |
      nickname |
      (nickname >> str('!') >> str('@') >> host)
    end

    # ( "#" / "+" / ( "!" channelid ) / "&" ) chanstring [ ":" chanstring ]
    rule :channel do
    end

    # hostname / hostaddr
    rule :host do
      hostname | hostaddr
    end

    # shortname *( "." shortname )
    rule :hostname do
      shortname >> (str('.') >> shortname).repeat
    end

    # ( letter / digit ) *( letter / digit / "-" ) *( letter / digit )
    # as specified in RFC 1123 [HNAME]
    rule :shortname do
      (letter | digit) >> (letter | digit | str('-') | str('/')).repeat >> (letter | digit).repeat
    end

    # ip4addr / ip6addr
    rule :hostaddr do
      ip4addr | ip6addr
    end

    # 1*3digit "." 1*3digit "." 1*3digit "." 1*3digit
    rule :ip4addr do
    end

    # 1*hexdigit 7( ":" 1*hexdigit ) /
    # "0:0:0:0:0:" ( "0" / "FFFF" ) ":" ip4addr
    rule :ip6addr do
    end

    # ( letter / special ) *8( letter / digit / special / "-" )
    # NOTE: freenode increased that to 16
    rule :nickname do
      (letter | special) >> (letter | digit | special | str('-')).repeat(0, 16)
    end

    # ( "$" / "#" ) mask
    # see details on allowed masks in section 3.3.1
    rule :targetmask do
      (str('$') | str('#')) >> mask
    end

    # %x01-07 / %x08-09 / %x0B-0C / %x0E-1F / %x21-2B / %x2D-39 / %x3B-FF
    # any octet except NUL, BELL, CR, LF, " ", "," and ":"
    rule :chanstring do
      match('[\x01-\x06\b-\t\v-\f\x0E-\x1F!-+\--9;-\x7f]').repeat(1)
    end

    # 5( %x41-5A / digit )   ; 5( A-Z / 0-9 )
    rule :channelid do
      match('[A-Z0-9]').repeat(5, 5)
    end

    # any 7-bit US_ASCII character,
    # except NUL, CR, LF, FF, h/v TABs, and " "
    #
    # NOTE: LIES, things really go wrong once it matches ","
    rule :key do
      match('[\x01-\b\x0E-\x1F!-+\--\x7f]').repeat(1, 23).as(:key)
    end

    # %x41-5A / %x61-7A ; A-Z / a-z
    rule :letter do
      match('[A-Za-z]')
    end

    # %x30-39 ; 0-9
    rule :digit do
      match('[0-9]')
    end

    # digit / "A" / "B" / "C" / "D" / "E" / "F"
    rule :hexdigit do
      match('[0-9A-Fa-f]')
    end

    # %x5B-60 / %x7B-7D
    # ; "[", "]", "\", "`", "_", "^", "{", "|", "}"
    rule :special do
      match('[\x5b-\x60\x7b-\x7d]')
    end
  end

  class Message
    def initialize
      @parser = MessageParser.new
    end

    def parse(io)
      io.encode!(Encoding::BINARY)
      msg = @parser.parse(io)

      fix_general(msg, :params, :param)

      msg
    end

    def root
      @parser.root
    end

    def fix_353(msg)
      fix_general(msg, :nicks, :nick)
    end

    def fix_JOIN(msg)
      fix_general(msg, :channels, :channel)
      fix_general(msg, :keys, :key)
    end

    # work around lack of transform support for array of hashes in parslet
    # transformer
    def fix_general(msg, plural, singular)
      case value = msg[plural]
      when Hash
        msg[plural] = [value[singular]]
      when Array
        msg[plural] = value.map{|h| h[singular] }
      end
    end
  end
end
