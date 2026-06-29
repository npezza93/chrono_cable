module ChronoCable::SolidCableAdapterListener
  def add_channel(channel, on_success)
    channels[channel] = last_id = last_message_id
    on_success.call(current_channel_id(channel)) if on_success
  end

  def current_channel_id(channel)
    SolidCable::Channel.find_by(
      channel_hash: SolidCable::Message.channel_hash_for(channel)
    )&.current_id.to_i
  end

  def broadcast_messages
    current_channels = channels.dup

    ::SolidCable::Message.
      broadcastable(current_channels.keys, last_id).
      each do |message|
        should_broadcast_message = false
        channels.compute_if_present(message.channel) do |channel_last_id|
          break if channel_last_id >= message.id

          should_broadcast_message = true
          message.id
        end

        broadcast(message.channel, message.action_cable_message) if should_broadcast_message
        self.last_id = message.id
      end
  end
end
