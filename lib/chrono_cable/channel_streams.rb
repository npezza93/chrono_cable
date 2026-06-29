module ChronoCable::ChannelStreams
  def stream_from(broadcasting, callback = nil, coder: nil, &block)
    return if unsubscribed?

    broadcasting = String(broadcasting)

    # Don't send the confirmation until pubsub#subscribe is successful
    defer_subscription_confirmation!

    # Build a stream handler by wrapping the user-provided callback with a decoder
    # or defaulting to a JSON-decoding retransmitter.
    user_handler = callback || block
    handler = worker_pool_stream_handler(broadcasting, user_handler, coder: coder)
    streams[broadcasting] = handler
    if user_handler
      history_streams.delete(broadcasting)
    else
      history_streams[broadcasting] = true
    end

    pubsub.subscribe(broadcasting, handler, lambda do |last_id = nil|
      confirmation_was_sent = subscription_confirmation_sent?

      record_subscription_confirmation_id broadcasting, last_id if history_stream?(broadcasting) && pubsub.supports_history?
      ensure_confirmation_sent

      logger.info "#{self.class.name} is streaming from #{broadcasting}"
    end)
  end

  def history_streams
    @history_streams ||= {}
  end

  def stop_all_streams
    super
    history_streams.clear
  end

  def stop_stream_from(broadcasting)
    super
    history_streams.delete(broadcasting)
  end

  def history_stream?(broadcasting)
    history_streams.key?(broadcasting)
  end

  def record_subscription_confirmation_id(broadcasting, id)
    return if id.nil?

    @subscription_confirmation_ids ||= {}
    @subscription_confirmation_ids[broadcasting] = id
  end

  def stream_decoder(handler = identity_handler, coder:)
    if coder
      -> message { handler.(coder.decode(message.try(:payload) || message)) }
    else
      -> message { handler.(message.try(:payload) || message) }
    end
  end

  def stream_transmitter(handler = identity_handler, broadcasting:)
    via = "streamed from #{broadcasting}"

    -> (message) do
      transmit handler.(message), via: via, id: message.try(:id), broadcasting:
    end
  end

  def __history(data = nil)
    broadcasting = data.to_h["broadcasting"]
    if pubsub.supports_history? && streams[broadcasting]
      message = {
        messages: pubsub.history(broadcasting, after_id: data["id"]),
        earliest_id: pubsub.earliest_id(broadcasting)
      }

      connection.transmit identifier: @identifier, broadcasting:,
        type: ActionCable::INTERNAL[:message_types][:history], message: message
    end
  end
end
