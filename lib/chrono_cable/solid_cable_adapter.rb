module ChronoCable::SolidCableAdapter
  def supports_history?
    true
  end

  def history(channel, after_id: nil)
    channel = channel_with_prefix(channel)
    messages = ::SolidCable::Message.
      where(channel_hash: ::SolidCable::Message.channel_hash_for(channel))
    messages = messages.where(channel_id: (after_id.to_i + 1)..) if after_id
    messages.order(:channel_id).map do |message|
      { id: message.channel_id, payload: message.payload }
    end
  end
end
