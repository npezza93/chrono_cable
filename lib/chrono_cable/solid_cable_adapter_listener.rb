module ChronoCable::SolidCableAdapterListener
  Broadcast = Data.define(:channel, :payload)

  def add_subscriber(channel, subscriber, on_success)
    if on_success
      callback = on_success
      on_success = -> { callback.call current_channel_id(channel) }
    end

    super
  end

  private
    def current_channel_id(channel)
      SolidCable::Message.
        where(channel_hash: SolidCable::Message.channel_hash_for(channel)).
        maximum(:channel_id).to_i
    end

    def broadcast(message)
      super Broadcast.new(message.channel, message.action_cable_message)
    end
end
