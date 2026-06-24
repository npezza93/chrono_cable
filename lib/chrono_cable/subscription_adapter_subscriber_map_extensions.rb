module ChronoCable::SubscriptionAdapterSubscriberMapExtensions
  def add_subscriber(channel, subscriber, on_success)
    @sync.synchronize do
      new_channel = !@subscribers.key?(channel)

      @subscribers[channel] << subscriber

      if new_channel
        add_channel channel, on_success
      elsif on_success
        on_success.call current_channel_id(channel)
      end
    end
  end

  def add_channel(channel, on_success)
    on_success.call current_channel_id(channel) if on_success
  end

  def current_channel_id(channel)
  end
end
