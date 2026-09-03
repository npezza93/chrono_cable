module ChronoCable::SolidCableBroadcasting
  Message = Struct.new(:channel, :payload, :channel_id, keyword_init: true)

  def broadcast(channel, payload)
    message = Message.new(channel:, payload:)
    channel_record = SolidCable::Channel.lookup(channel)

    if channel_record.deliver_in_order?
      channel_record.with_lock do
        channel_record.increment!(:current_id)
        message.channel_id = channel_record.current_id
      end
    end

    queue.enq message
  rescue ClosedQueueError
    raise SolidCable::BatchedBroadcaster::Stopped, "Solid Cable writer has stopped"
  end
end
