module ChronoCable::ChannelStreams
  def stream_from(broadcasting, callback = nil, coder: nil, deliver_in_order: false, &block)
    return if unsubscribed?

    broadcasting = String(broadcasting)
    ordered = deliver_in_order && pubsub.supports_history?

    ordered_streams.delete broadcasting
    pubsub.enable_ordered_delivery(broadcasting) if ordered

    # Don't send the confirmation until pubsub#subscribe is successful
    defer_subscription_confirmation!

    # Build a stream handler by wrapping the user-provided callback with a decoder
    # or defaulting to a JSON-decoding retransmitter.
    user_handler = callback || block
    handler = worker_pool_stream_handler(broadcasting, user_handler, coder: coder)
    streams[broadcasting] = handler

    if ordered
      ordered_streams[broadcasting] = user_handler && stream_handler(broadcasting, user_handler, coder:)
    end

    pubsub.subscribe(broadcasting, handler, lambda do |last_id = nil|
      confirmation_was_sent = subscription_confirmation_sent?

      record_subscription_confirmation_id broadcasting, last_id if ordered_stream?(broadcasting)
      ensure_confirmation_sent
      transmit_subscription_id broadcasting, last_id if confirmation_was_sent

      logger.info "#{self.class.name} is streaming from #{broadcasting}"
    end)
  end

  def stop_all_streams
    super
    ordered_streams.clear
  end

  def stop_stream_from(broadcasting)
    broadcasting = String(broadcasting)
    super
    ordered_streams.delete broadcasting
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

        params = { via: via }
        params.merge!(id: message.try(:id), broadcasting:) if ordered_stream?(broadcasting)
        transmit data, **params
      end
    end

    def ordered_streams
      @ordered_streams ||= {}
    end

    def ordered_stream?(broadcasting)
      ordered_streams.key? broadcasting
    end

    def record_subscription_confirmation_id(broadcasting, id)
      return if id.nil?

      @subscription_confirmation_ids ||= {}
      @subscription_confirmation_ids[ChronoCable.signed_stream_verifier.generate(broadcasting)] = id
    end

    def __history(data = nil)
      signed_broadcasting = data.to_h["broadcasting"]
      return unless signed_broadcasting.is_a?(String)

      broadcasting = ChronoCable.signed_stream_verifier.verified(signed_broadcasting)
      return unless ordered_stream?(broadcasting)

      messages = pubsub.history(broadcasting, after_id: data["id"])
      if handler = ordered_streams[broadcasting]
        messages.each do |message|
          handler.call ActionCable::SubscriptionAdapter::Message.new(
            id: message[:id], payload: message[:payload]
          )
        end
        transmit_history [], broadcasting:
      else
        transmit_history messages, broadcasting:
      end
    end

    def transmit_subscription_id(broadcasting, id)
      return unless ordered_stream?(broadcasting) && id

      transmit_history [], broadcasting:, id:
    end

    def transmit_history(messages, broadcasting:, id: nil)
      message = { messages:, id: }.compact
      broadcasting = ChronoCable.signed_stream_verifier.generate(broadcasting)

      connection.transmit identifier: @identifier, broadcasting:,
        type: ActionCable::INTERNAL[:message_types][:history], message: message
    end
end
