module ChronoCable::SolidCableBroadcasting
  Message = Struct.new(:channel, :payload, :channel_id, keyword_init: true)

  def broadcast(channel, payload)
    channel_record = SolidCable::Channel.
      create_or_find_by!(channel_hash: SolidCable::Message.channel_hash_for(channel))
    channel_record.with_lock do
      channel_record.increment!(:current_id)
      message = Message.new(channel:, payload:, channel_id: channel_record.current_id)

      queue.enq message
    end
  rescue ClosedQueueError
    raise SolidCable::BatchedBroadcaster::Stopped, "Solid Cable writer has stopped"
  end
end
