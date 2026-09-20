require "chrono_cable/version"
require "chrono_cable/engine"

require "action_cable/subscription_adapter/message"

require "chrono_cable/subscription_adapter_base_extensions"
require "chrono_cable/connection_subscriptions"
require "chrono_cable/channel_base"
require "chrono_cable/channel_streams"
require "chrono_cable/turbo_streams_channel"

require "chrono_cable/solid_cable_message_class_methods"
require "chrono_cable/solid_cable_adapter_listener"
require "chrono_cable/solid_cable_adapter"
require "chrono_cable/solid_cable_broadcasting"

module ChronoCable
  def self.signed_stream_verifier
    Rails.application.message_verifier("chrono_cable/stream_name")
  end

  def self.install!
    ::ActionCable::INTERNAL[:message_types][:history] = "history"

    ::ActionCable::SubscriptionAdapter::Base.include ::ChronoCable::SubscriptionAdapterBaseExtensions

    ::ActionCable::Connection::Subscriptions.prepend ChronoCable::ConnectionSubscriptions
    ::ActionCable::Channel::Base.prepend ChronoCable::ChannelBase
    ::ActionCable::Channel::Streams.prepend ChronoCable::ChannelStreams
    ::Turbo::StreamsChannel.prepend ChronoCable::TurboStreamsChannel if defined?(::Turbo::StreamsChannel)

    ::ActionCable::SubscriptionAdapter::SolidCable::Listener.prepend ::ChronoCable::SolidCableAdapterListener
    ::ActionCable::SubscriptionAdapter::SolidCable.include ChronoCable::SolidCableAdapter

    SolidCable::BatchedBroadcaster.prepend ::ChronoCable::SolidCableBroadcasting
    SolidCable::Message.singleton_class.prepend ::ChronoCable::SolidCableMessageClassMethods
  end
end
