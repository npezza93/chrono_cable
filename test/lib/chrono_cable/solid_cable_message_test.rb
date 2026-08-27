require "test_helper"

class ChronoCable::SolidCableMessageTest < ActiveSupport::TestCase
  setup do
    SolidCable::Message.delete_all
  end

  test "persists a batch with its per-channel ids" do
    messages = [
      broadcast("messages", "first", 1),
      broadcast("messages", "second", 2),
      broadcast("notifications", "other", 1)
    ]

    broadcast_batch messages

    assert_equal [
      [ "messages", "first", 1 ],
      [ "messages", "second", 2 ],
      [ "notifications", "other", 1 ]
    ], SolidCable::Message.order(:id).pluck(:channel, :payload, :channel_id)
  end

  test "turns a persisted message into an Action Cable message" do
    record = SolidCable::Message.create!(
      channel: "messages",
      channel_hash: SolidCable::Message.channel_hash_for("messages"),
      channel_id: 7,
      payload: "payload"
    )

    message = ChronoCable::SolidCableMessage.
      instance_method(:action_cable_message).
      bind_call(record)

    assert_equal 7, message.id
    assert_equal "payload", message.payload
  end

  private
    def broadcast(channel, payload, channel_id)
      ChronoCable::SolidCableBroadcasting::Message.new(channel:, payload:, channel_id:)
    end

    def broadcast_batch(messages)
      ChronoCable::SolidCableMessage::BroadcastingClassMethods.
        instance_method(:broadcast_batch).
        bind_call(SolidCable::Message, messages)
    end
end
