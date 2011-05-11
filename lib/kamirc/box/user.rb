module KamIRC
  # +o : operator flag
  USER_OP        = 0b01000000
  # +O : local operator flag
  USER_LOCAL_OP  = 0b00100000
  # +r : restricted user connection
  USER_RESTRICTED= 0b00010000
  # +i : marks a users as invisible (as in RFC)
  USER_INVISIBLE = 0b00001000
  # +w : user receives wallops (as in RFC)
  USER_WALLOPS   = 0b00000100
  # +s : marks a user for receipt of server notices
  USSER_NOTICES  = 0b00000010
  # +a : user is flagged as away
  USER_AWAY      = 0b00000001

  module Box
    class User < Struct.new(:cmd, :nick, :flags, :reserved, :realname)
      REGISTER['USER'] = self

      def self.from_message(msg)
        p msg
        new('USER', *msg[:params].map(&:to_s))
      end

      def to_message
        "USER #{nick} #{flags} #{reserved} :#{realname}"
      end
    end

    def self.User(hash = {})
      User.new.tap do |instance|
        instance.cmd = 'USER'
        hash.each{|key, value| instance[key] = value }
      end
    end
  end
end
