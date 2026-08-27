require "test_helper"

class ChronoCable::SolidCableAdapterListenerTest < ActiveSupport::TestCase
  class Listener
    prepend ChronoCable::SolidCableAdapterListener

    attr_reader :broadcasted

    def add_subscriber(_channel, _subscriber, on_success)
      on_success&.call
    end

    private
      def broadcast(channel, message)
        @broadcasted = [ channel, message ]
      end
  end

  setup do
    SolidCable::Channel.delete_all
    SolidCable::Message.delete_all
  end

  test "subscription id is the latest persisted message rather than the reserved channel id" do
    channel = "messages"
    channel_hash = SolidCable::Message.channel_hash_for(channel)

    SolidCable::Channel.create!(channel_hash:, current_id: 2)

    assert_equal 0, current_channel_id(channel)

    SolidCable::Message.create!(channel:, channel_hash:, channel_id: 1, payload: "first")

    assert_equal 1, current_channel_id(channel)
  end

  test "passes the persisted channel id to the subscription callback" do
    channel = "messages"
    SolidCable::Message.create!(
      channel:,
      channel_hash: SolidCable::Message.channel_hash_for(channel),
      channel_id: 3,
      payload: "third"
    )
    received_id = nil

    Listener.new.add_subscriber(channel, -> { }, ->(id) { received_id = id })

    assert_equal 3, received_id
  end

  test "wraps broadcast payloads with their channel id" do
    listener = Listener.new
    record = SolidCable::Message.create!(
      channel: "messages",
      channel_hash: SolidCable::Message.channel_hash_for("messages"),
      channel_id: 5,
      payload: "payload"
    )
    record.extend ChronoCable::SolidCableMessage

    listener.__send__(:broadcast, record)

    channel, message = listener.broadcasted
    assert_equal "messages", channel
    assert_equal 5, message.id
    assert_equal "payload", message.payload
  end

  private
    def current_channel_id(channel)
      @current_channel_id_reader ||= Class.new do
        include ChronoCable::SolidCableAdapterListener

        public :current_channel_id
      end.new

      @current_channel_id_reader.current_channel_id(channel)
    end
end
