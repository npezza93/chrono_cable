# frozen_string_literal: true

require "solid_cable"

module SolidCable
  class Channel < ::SolidCable::Record
    def self.lookup(channel)
      channel_hash = ::SolidCable::Message.channel_hash_for(channel)
      find_by(channel_hash:) || create_or_find_by!(channel_hash:)
    end
  end
end
