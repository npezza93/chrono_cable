require "test_helper"

class ChronoCableTest < ActiveSupport::TestCase
  test "installs every Action Cable and Solid Cable extension" do
    ChronoCable.install!

    assert_equal "history", ActionCable::INTERNAL[:message_types][:history]
    assert_includes ActionCable::SubscriptionAdapter::Base.ancestors,
      ChronoCable::SubscriptionAdapterBaseExtensions
    assert_includes ActionCable::Connection::Subscriptions.ancestors,
      ChronoCable::ConnectionSubscriptions
    assert_includes ActionCable::Channel::Base.ancestors, ChronoCable::ChannelBase
    assert_includes ActionCable::Channel::Streams.ancestors, ChronoCable::ChannelStreams
    assert_includes ActionCable::SubscriptionAdapter::SolidCable::Listener.ancestors,
      ChronoCable::SolidCableAdapterListener
    assert_includes ActionCable::SubscriptionAdapter::SolidCable.ancestors,
      ChronoCable::SolidCableAdapter
    assert_includes SolidCable::BatchedBroadcaster.ancestors,
      ChronoCable::SolidCableBroadcasting
    assert_includes SolidCable::Message.singleton_class.ancestors,
      ChronoCable::SolidCableMessage::BroadcastingClassMethods
    assert_includes SolidCable::Message.ancestors, ChronoCable::SolidCableMessage
  end
end
