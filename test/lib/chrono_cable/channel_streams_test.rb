require "test_helper"

class ChronoCable::ChannelStreamsTest < ActiveSupport::TestCase
  class Pubsub
    attr_accessor :history_messages, :earliest
    attr_reader :history_requests

    def initialize(ids: {}, supports_history: true)
      @ids = ids
      @supports_history = supports_history
      @subscribers = {}
      @history_messages = []
      @history_requests = []
    end

    def subscribe(channel, handler, on_success)
      @subscribers[channel] = handler
      on_success.call @ids.fetch(channel, 0)
    end

    def unsubscribe(channel, _handler)
      @subscribers.delete channel
    end

    def publish(channel, message)
      @subscribers.fetch(channel).call message
    end

    def supports_history?
      @supports_history
    end

    def history(channel, after_id:)
      @history_requests << [ channel, after_id ]
      history_messages
    end

    def earliest_id(_channel)
      earliest
    end
  end

  class Connection
    attr_reader :identifiers, :logger, :pubsub, :transmissions

    def initialize(pubsub)
      @identifiers = []
      @logger = ActiveSupport::Logger.new(nil)
      @pubsub = pubsub
      @transmissions = []
    end

    def transmit(**data)
      transmissions << data
    end

    def perform_work(receiver, method, *args)
      receiver.public_send(method, *args)
    end
  end

  class Channel < ActionCable::Channel::Base
    def subscribed
      stream_from "messages"
    end
  end

  test "includes stream ids in the subscription confirmation" do
    channel, connection = subscribe(ids: { "messages" => 6 })

    assert channel.__send__(:subscription_confirmation_sent?)
    assert_equal({
      identifier: identifier,
      type: ActionCable::INTERNAL[:message_types][:confirmation],
      ids: { "messages" => 6 }
    }, connection.transmissions.last)
  end

  test "transmits live messages with their id and broadcasting" do
    _channel, connection, pubsub = subscribe(ids: { "messages" => 3 })
    connection.transmissions.clear

    pubsub.publish "messages", ActionCable::SubscriptionAdapter::Message.new(
      id: 4,
      payload: ActiveSupport::JSON.encode(body: "hello")
    )

    assert_equal({
      identifier: identifier,
      message: { "body" => "hello" },
      broadcasting: "messages",
      id: 4
    }, connection.transmissions.last)
  end

  test "returns history only for a subscribed default stream" do
    channel, connection, pubsub = subscribe(ids: { "messages" => 3 })
    pubsub.history_messages = [ { id: 4, payload: "next" } ]
    pubsub.earliest = 2
    connection.transmissions.clear

    channel.__send__(:__history, "broadcasting" => "messages", "id" => 3)

    assert_equal [ [ "messages", 3 ] ], pubsub.history_requests
    assert_equal({
      identifier: identifier,
      broadcasting: "messages",
      type: ActionCable::INTERNAL[:message_types][:history],
      message: {
        messages: [ { id: 4, payload: "next" } ],
        earliest_id: 2
      }
    }, connection.transmissions.last)

    channel.__send__(:__history, "broadcasting" => "not-subscribed", "id" => 3)
    assert_equal 1, connection.transmissions.size
  end

  test "custom stream callbacks receive live and historical payloads" do
    channel, connection, pubsub = subscribe
    received = []
    channel.stream_from("custom", ->(message) { received << message }, coder: ActiveSupport::JSON)
    connection.transmissions.clear

    pubsub.publish "custom", ActionCable::SubscriptionAdapter::Message.new(
      id: 9,
      payload: ActiveSupport::JSON.encode(body: "custom")
    )
    pubsub.history_messages = [
      { id: 10, payload: ActiveSupport::JSON.encode(body: "historical") }
    ]
    channel.__send__(:__history, "broadcasting" => "custom", "id" => 9)

    assert_equal [
      { "body" => "custom" },
      { "body" => "historical" }
    ], received
    assert_equal [ [ "custom", 9 ] ], pubsub.history_requests
    assert_equal({
      identifier: identifier,
      broadcasting: "custom",
      type: ActionCable::INTERNAL[:message_types][:history],
      message: { messages: [] }
    }, connection.transmissions.last)
  end

  test "a stream added after confirmation receives its own starting id" do
    channel, connection, _pubsub = subscribe(ids: { "messages" => 3, "later" => 8 })
    connection.transmissions.clear

    channel.stream_from "later"

    assert_equal({
      identifier: identifier,
      broadcasting: "later",
      type: ActionCable::INTERNAL[:message_types][:history],
      message: { messages: [], id: 8 }
    }, connection.transmissions.last)
  end

  test "stopping a stream removes its history access" do
    channel, connection, pubsub = subscribe
    channel.stop_stream_from "messages"
    connection.transmissions.clear

    channel.__send__(:__history, "broadcasting" => "messages", "id" => 0)

    assert_empty connection.transmissions
    assert_empty pubsub.history_requests
  end

  test "an adapter without history support sends a standard confirmation" do
    _channel, connection = subscribe(supports_history: false)

    assert_equal({
      identifier: identifier,
      type: ActionCable::INTERNAL[:message_types][:confirmation]
    }, connection.transmissions.last)
  end

  private
    def subscribe(ids: {}, supports_history: true)
      pubsub = Pubsub.new(ids:, supports_history:)
      connection = Connection.new(pubsub)
      channel = Channel.new(connection, identifier)
      channel.subscribe_to_channel

      [ channel, connection, pubsub ]
    end

    def identifier
      '{"channel":"ChronoCable::ChannelStreamsTest::Channel"}'
    end
end
