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
      history_streams[broadcasting] = stream_handler(broadcasting, user_handler, coder:)
    end

    pubsub.subscribe(broadcasting, handler, lambda do |last_id = nil|
      confirmation_was_sent = subscription_confirmation_sent?

      record_subscription_confirmation_id broadcasting, last_id if history_stream?(broadcasting) && pubsub.supports_history?
      ensure_confirmation_sent
      transmit_subscription_id broadcasting, last_id if confirmation_was_sent

      logger.info "#{self.class.name} is streaming from #{broadcasting}"
    end)
  end

  def stop_all_streams
    super
    history_streams.clear
  end

  def stop_stream_from(broadcasting)
    broadcasting = String(broadcasting)
    super
    history_streams.delete(broadcasting)
  end

  private
    def stream_decoder(handler = nil, coder:)
      ->(message) do
        payload = message.try(:payload) || message
        payload = coder.decode(payload) if coder

        handler ? handler.(payload) : payload
      end
    end

    def stream_transmitter(handler = nil, broadcasting:)
      via = "streamed from #{broadcasting}"

      ->(message) do
        data =
          if handler
            handler.(message)
          else
            message
          end

        transmit data, via: via, id: message.try(:id), broadcasting:
      end
    end

    def history_streams
      @history_streams ||= {}
    end

    def history_stream?(broadcasting)
      history_streams.key?(broadcasting)
    end

    def record_subscription_confirmation_id(broadcasting, id)
      return if id.nil?

      @subscription_confirmation_ids ||= {}
      @subscription_confirmation_ids[broadcasting] = id
    end

    def __history(data = nil)
      broadcasting = data.to_h["broadcasting"]
      return unless broadcasting

      broadcasting = String(broadcasting)
      if pubsub.supports_history? && history_stream?(broadcasting)
        messages = pubsub.history(broadcasting, after_id: data["id"])
        history_handler = history_streams[broadcasting]

        if history_handler
          replay_history messages, with: history_handler
          transmit_history [], broadcasting:
        else
          transmit_history messages, broadcasting:
        end
      end
    end

    def replay_history(messages, with:)
      messages.each do |message|
        with.call ActionCable::SubscriptionAdapter::Message.new(
          id: message[:id], payload: message[:payload]
        )
      end
    end

    def transmit_subscription_id(broadcasting, id)
      return unless history_stream?(broadcasting) && pubsub.supports_history? && id

      transmit_history [], broadcasting:, id:
    end

    def transmit_history(messages, broadcasting:, id: nil)
      message = {
        messages:,
        earliest_id: pubsub.earliest_id(broadcasting),
        id:
      }.compact

      connection.transmit identifier: @identifier, broadcasting:,
        type: ActionCable::INTERNAL[:message_types][:history], message: message
    end
end
