require "chrono_cable/version"
require "chrono_cable/engine"

require "action_cable/subscription_adapter/message"

require "chrono_cable/subscription_adapter_base_extensions"
require "chrono_cable/subscription_adapter_subscriber_map_extensions"
require "chrono_cable/connection_subscriptions"
require "chrono_cable/channel_base"
require "chrono_cable/channel_streams"

require "chrono_cable/solid_cable_message"
require "chrono_cable/solid_cable_adapter_listener"
require "chrono_cable/solid_cable_adapter"

module ChronoCable
  def self.install!
    ::ActionCable::INTERNAL[:message_types][:history] = "history"

    ::ActionCable::SubscriptionAdapter::Base.include ::ChronoCable::SubscriptionAdapterBaseExtensions
    ::ActionCable::SubscriptionAdapter::SubscriberMap.prepend ::ChronoCable::SubscriptionAdapterSubscriberMapExtensions

    ::ActionCable::Connection::Subscriptions.prepend ChronoCable::ConnectionSubscriptions
    ::ActionCable::Channel::Base.prepend ChronoCable::ChannelBase
    ::ActionCable::Channel::Streams.prepend ChronoCable::ChannelStreams

    ::ActionCable::SubscriptionAdapter::SolidCable::Listener.prepend ::ChronoCable::SolidCableAdapterListener
    ::ActionCable::SubscriptionAdapter::SolidCable.include ChronoCable::SolidCableAdapter


    SolidCable::Message.prepend ::ChronoCable::SolidCableMessage
  end
end
