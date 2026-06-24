module ChronoCable::SolidCableMessage
  def action_cable_message
    if defined?(::ActionCable::SubscriptionAdapter::Message)
      ::ActionCable::SubscriptionAdapter::Message.new(payload:, id: )
    else
      payload
    end
  end
end
