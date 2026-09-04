module ChronoCable::SolidCableMessageClassMethods
  def broadcast_batch(broadcasts)
    created_at = Time.current
    insert_all broadcasts.map { |message|
      { created_at:, channel: message.channel, channel_id: message.channel_id,
        payload: message.payload, channel_hash: channel_hash_for(message.channel) }
    }
  end
end
