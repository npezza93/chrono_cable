require "test_helper"

class ChronoCable::SolidCableBroadcastingTest < ActiveSupport::TestCase
  class Broadcaster
    include ChronoCable::SolidCableBroadcasting

    attr_reader :queue

    def initialize
      @queue = Queue.new
    end
  end

  setup do
    SolidCable::Channel.delete_all
  end

  test "assigns ids only to ordered channels" do
    broadcaster = Broadcaster.new
    SolidCable::Channel.create!(channel_hash: channel_hash("notifications"), deliver_in_order: true)

    broadcaster.broadcast "messages", "unordered"
    channel_record("messages").update!(deliver_in_order: true)
    broadcaster.broadcast "messages", "first"
    broadcaster.broadcast "messages", "second"
    broadcaster.broadcast "notifications", "other"

    unordered, first, second, other = 4.times.map { broadcaster.queue.pop }

    assert_nil unordered.channel_id
    assert_equal [ "messages", "first", 1 ], first.values
    assert_equal [ "messages", "second", 2 ], second.values
    assert_equal [ "notifications", "other", 1 ], other.values
    assert_equal 2, channel_record("messages").current_id
    assert_equal 1, channel_record("notifications").current_id

    SolidCable::Message.broadcast_batch [ unordered, first, second, other ]

    assert_equal [
      [ "messages", "unordered", nil ],
      [ "messages", "first", 1 ],
      [ "messages", "second", 2 ],
      [ "notifications", "other", 1 ]
    ], SolidCable::Message.order(:id).pluck(:channel, :payload, :channel_id)
  end

  test "raises the Solid Cable stopped error when the queue is closed" do
    broadcaster = Broadcaster.new
    broadcaster.queue.close

    error = assert_raises(SolidCable::BatchedBroadcaster::Stopped) do
      broadcaster.broadcast "messages", "payload"
    end

    assert_equal "Solid Cable writer has stopped", error.message
    assert_equal 0, channel_record("messages").current_id
  end

  private
    def channel_record(channel)
      SolidCable::Channel.find_by!(channel_hash: channel_hash(channel))
    end

    def channel_hash(channel)
      SolidCable::Message.channel_hash_for(channel)
    end
end
