module KamIRC
  # The NOTICE command is used similarly to PRIVMSG. The difference between
  # NOTICE and PRIVMSG is that automatic replies MUST NEVER be sent in response
  # to a NOTICE message. This rule applies to servers too - they MUST NOT send
  # any error reply back to the client on receipt of a notice. The object of
  # this rule is to avoid loops between clients automatically sending something
  # in response to something it received.
  #
  # This command is available to services as well as users.
  #
  # This is typically used by services, and automatons (clients with either an
  # AI or other interactive program controlling their actions).
  #
  # See PRIVMSG for more details on replies and examples.
  module Box
    class Notice < Struct.new(:from, :cmd, :target, :text)
      REGISTER['NOTICE'] = self

      def self.from_message(msg)
        new(msg[:prefix], 'NOTICE', *msg[:params])
      end
    end
  end
end
