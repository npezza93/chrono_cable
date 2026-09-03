module ChronoCable::SolidCableAdapter
  def supports_history?
    true
  end

  def history(channel, after_id: nil)
    messages = ::SolidCable::Message.
      where(channel_hash: channel_hash_for(channel))
    messages = messages.where(channel_id: (after_id.to_i + 1)..) if after_id
    messages.order(:channel_id).map do |message|
      { id: message.channel_id, payload: message.payload }
    end
  end

  def earliest_id(channel)
    ::SolidCable::Message.where(channel_hash: channel_hash_for(channel)).minimum(:channel_id)
  end

  def enable_ordered_delivery(channel)
    channel = ::SolidCable::Channel.lookup(channel_with_prefix(channel))

    channel.update_columns(deliver_in_order: true) unless channel.deliver_in_order?
  end

  private
    def channel_hash_for(channel)
      ::SolidCable::Message.channel_hash_for channel_with_prefix(channel)
    end
end
