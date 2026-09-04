require "test_helper"

class ChronoCable::SolidCableAdapterListenerTest < ActiveSupport::TestCase
  class Listener
    prepend ChronoCable::SolidCableAdapterListener

    attr_reader :broadcasted

    def add_subscriber(_channel, _subscriber, on_success)
      on_success&.call
    end

    def deliver(message)
      broadcast message
    end

    private
      def broadcast(message)
        @broadcasted = [ message.channel, message.payload ]
      end
  end

  setup do
    SolidCable::Channel.delete_all
    SolidCable::Message.delete_all
  end

  test "reports the latest persisted id when subscribing" do
    channel = "messages"
    channel_hash = SolidCable::Message.channel_hash_for(channel)
    SolidCable::Channel.create!(channel_hash:, current_id: 2)
    received_ids = []

    Listener.new.add_subscriber(channel, -> { }, ->(id) { received_ids << id })

    SolidCable::Message.create!(channel:, channel_hash:, channel_id: 1, payload: "first")
    Listener.new.add_subscriber(channel, -> { }, ->(id) { received_ids << id })

    assert_equal [ 0, 1 ], received_ids
  end

  test "wraps broadcast payloads with their channel id" do
    listener = Listener.new
    record = SolidCable::Message.create!(
      channel: "messages",
      channel_hash: SolidCable::Message.channel_hash_for("messages"),
      channel_id: 5,
      payload: "payload"
    )
    listener.deliver record

    channel, message = listener.broadcasted
    assert_equal "messages", channel
    assert_equal 5, message.id
    assert_equal "payload", message.payload
  end
end
