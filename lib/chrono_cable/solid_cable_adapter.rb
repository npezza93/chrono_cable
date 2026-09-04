module ChronoCable::SolidCableAdapter
  def supports_history?
    true
  end

  def history(channel, after_id: nil)
    messages = ::SolidCable::Message.
      where(channel_hash: channel_hash_for(channel)).
      where.not(channel_id: nil)
    messages = messages.where(channel_id: (after_id.to_i + 1)..) if after_id
    messages.order(:channel_id).pluck(:channel_id, :payload).map do |id, payload|
      { id:, payload: }
    end
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
