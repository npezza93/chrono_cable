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
  end

  test "returns ordered history after the requested channel id" do
    create_message "room", 3, "third"
    create_message "room", 1, "first"
    create_message "other", 2, "not included"
    create_message "room", 2, "second"

    assert adapter.supports_history?
    assert_equal [
      { id: 2, payload: "second" },
      { id: 3, payload: "third" }
    ], adapter.history("room", after_id: 1)
  end

  test "returns all channel history when no id is supplied" do
    create_message "room", 2, "second"
    create_message "room", 1, "first"

    assert_equal [
      { id: 1, payload: "first" },
      { id: 2, payload: "second" }
    ], adapter.history("room")
  end

  test "returns the earliest retained channel id" do
    create_message "room", 4, "fourth"
    create_message "room", 7, "seventh"
    create_message "other", 1, "not included"

    assert_equal 4, adapter.earliest_id("room")
    assert_nil adapter.earliest_id("missing")
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
end
