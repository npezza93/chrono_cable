module ChronoCable::SolidCableAdapterListener
  def add_subscriber(channel, subscriber, on_success)
    if on_success
      callback = on_success
      on_success = -> { callback.call current_channel_id(channel) }
    end

    super
  end

  private
    def current_channel_id(channel)
      SolidCable::Channel.find_by(
        channel_hash: SolidCable::Message.channel_hash_for(channel)
      )&.current_id.to_i
    end

    def broadcast(message)
      super(message.channel, message.action_cable_message)
    end
end
