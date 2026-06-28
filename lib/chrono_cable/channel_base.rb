module ChronoCable::ChannelBase
  private
    def transmit(data, via: nil, id: nil, broadcasting: nil) # :doc:
      logger.debug do
        status = "#{self.class.name} transmitting #{data.inspect.truncate(300)}"
        status += " (via #{via})" if via
        status
      end

      payload = { channel_class: self.class.name, data: data, via: via }
      ActiveSupport::Notifications.instrument("transmit.action_cable", payload) do
        connection.transmit **{ identifier: @identifier, message: data, broadcasting:, id: }.compact
      end
    end

    def transmit_subscription_confirmation
      unless subscription_confirmation_sent?
        logger.debug "#{self.class.name} is transmitting the subscription confirmation"

        ActiveSupport::Notifications.instrument("transmit_subscription_confirmation.action_cable", channel_class: self.class.name, identifier: @identifier) do
          connection.transmit **{ identifier: @identifier,
            type: ActionCable::INTERNAL[:message_types][:confirmation],
            ids: @subscription_confirmation_ids
          }.compact
          @subscription_confirmation_sent = true
        end
      end
    end
end
