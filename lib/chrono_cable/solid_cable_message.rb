module ChronoCable::SolidCableMessage
  class << self
    def broadcast(channel, payload)
      channel_hash = channel_hash_for(channel)

      transaction do
        channel_record = SolidCable::Channel.create_or_find_by!(channel_hash:)
        channel_record.with_lock do
          channel_record.increment!(:current_id)

          insert({ created_at: Time.current, channel:, payload:, channel_hash:,
            channel_id: channel_record.current_id })
        end
      end
    end
  end

  def action_cable_message
    if defined?(::ActionCable::SubscriptionAdapter::Message)
      ::ActionCable::SubscriptionAdapter::Message.new(payload:, id: channel_id)
    else
      payload
    end
  end
end
