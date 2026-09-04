require "test_helper"

class ChronoCable::SolidCableAdapterTest < ActiveSupport::TestCase
  class Adapter
    include ChronoCable::SolidCableAdapter

    private
      def channel_with_prefix(channel)
        "dummy:#{channel}"
      end
  end

  setup do
    SolidCable::Message.delete_all
    SolidCable::Channel.delete_all
  end

  test "returns ordered, numbered history for the requested channel" do
    create_message "room", 3, "third"
    create_message "room", 1, "first"
    create_message "room", nil, "unordered"
    create_message "other", 2, "not included"
    create_message "room", 2, "second"

    assert_equal [
      { id: 1, payload: "first" },
      { id: 2, payload: "second" },
      { id: 3, payload: "third" }
    ], adapter.history("room")
    assert_equal [
      { id: 2, payload: "second" },
      { id: 3, payload: "third" }
    ], adapter.history("room", after_id: 1)
  end

  test "enables ordered delivery" do
    adapter.enable_ordered_delivery "room"

    channel = SolidCable::Channel.find_by!(channel_hash: channel_hash("room"))
    assert channel.reload.deliver_in_order?
  end

  private
    def adapter
      @adapter ||= Adapter.new
    end

    def create_message(channel, channel_id, payload)
      channel = "dummy:#{channel}"
      SolidCable::Message.create!(
        channel:,
        channel_hash: SolidCable::Message.channel_hash_for(channel),
        channel_id:,
        payload:
      )
    end

    def channel_hash(channel)
      SolidCable::Message.channel_hash_for("dummy:#{channel}")
    end
end
