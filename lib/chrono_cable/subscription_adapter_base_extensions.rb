module ChronoCable::SubscriptionAdapterBaseExtensions
  def supports_history?
    false
  end

  def history(channel, after_id: nil)
    raise NotImplementedError
  end
end
