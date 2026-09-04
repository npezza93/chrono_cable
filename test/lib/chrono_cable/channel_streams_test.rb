require "test_helper"

class ChronoCable::ChannelStreamsTest < ActiveSupport::TestCase
  class Pubsub
    attr_accessor :history_messages
    attr_reader :history_requests, :stream_orderings

    def initialize(ids: {}, supports_history: true)
      @ids = ids
      @supports_history = supports_history
      @subscribers = {}
      @history_messages = []
      @history_requests = []
      @stream_orderings = {}
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

    def enable_ordered_delivery(channel)
      stream_orderings[channel] = true
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
    class_attribute :subscriber

    def subscribed
      self.class.subscriber = self
      stream_from "messages", deliver_in_order: true
    end
  end

  test "transmits the starting and live stream ids" do
    _channel, connection, pubsub = subscribe(ids: { "messages" => 6 })

    assert_equal({
      identifier: identifier,
      type: ActionCable::INTERNAL[:message_types][:confirmation],
      ids: { "messages" => 6 }
    }, connection.transmissions.last)
    connection.transmissions.clear

    pubsub.publish "messages", ActionCable::SubscriptionAdapter::Message.new(
      id: 7,
      payload: ActiveSupport::JSON.encode(body: "hello")
    )

    assert_equal({
      identifier: identifier,
      message: { "body" => "hello" },
      broadcasting: "messages",
      id: 7
    }, connection.transmissions.last)
  end

  test "streams are unordered by default" do
    channel, connection, pubsub, subscriptions = subscribe
    connection.transmissions.clear

    channel.stream_from "metrics"
    connection.transmissions.clear
    pubsub.publish "metrics", ActionCable::SubscriptionAdapter::Message.new(
      id: 7,
      payload: ActiveSupport::JSON.encode(body: "hello")
    )

    assert_not pubsub.stream_orderings.key?("metrics")
    assert_equal({
      identifier: identifier,
      message: { "body" => "hello" }
    }, connection.transmissions.last)

    request_history subscriptions, "metrics", 0
    assert_empty pubsub.history_requests
  end

  test "returns history only while the stream is subscribed" do
    channel, connection, pubsub, subscriptions = subscribe(ids: { "messages" => 3 })
    pubsub.history_messages = [ { id: 4, payload: "next" } ]
    connection.transmissions.clear

    request_history subscriptions, "messages", 3

    assert_equal [ [ "messages", 3 ] ], pubsub.history_requests
    assert_equal({
      identifier: identifier,
      broadcasting: "messages",
      type: ActionCable::INTERNAL[:message_types][:history],
      message: {
        messages: [ { id: 4, payload: "next" } ]
      }
    }, connection.transmissions.last)

    request_history subscriptions, "not-subscribed", 3
    assert_equal 1, connection.transmissions.size

    channel.stop_stream_from "messages"
    connection.transmissions.clear

    request_history subscriptions, "messages", 0

    assert_empty connection.transmissions
    assert_equal [ [ "messages", 3 ] ], pubsub.history_requests
  end

  test "custom stream callbacks receive live and historical payloads" do
    channel, connection, pubsub, subscriptions = subscribe
    received = []
    channel.stream_from("custom", ->(message) { received << message },
      coder: ActiveSupport::JSON, deliver_in_order: true)
    connection.transmissions.clear

    pubsub.publish "custom", ActionCable::SubscriptionAdapter::Message.new(
      id: 9,
      payload: ActiveSupport::JSON.encode(body: "custom")
    )
    pubsub.history_messages = [
      { id: 10, payload: ActiveSupport::JSON.encode(body: "historical") }
    ]
    request_history subscriptions, "custom", 9

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

    channel.stream_from "later", deliver_in_order: true

    assert_equal({
      identifier: identifier,
      broadcasting: "later",
      type: ActionCable::INTERNAL[:message_types][:history],
      message: { messages: [], id: 8 }
    }, connection.transmissions.last)
  end

  test "an adapter without history support sends a standard confirmation" do
    _channel, connection, pubsub = subscribe(supports_history: false)

    assert_equal({
      identifier: identifier,
      type: ActionCable::INTERNAL[:message_types][:confirmation]
    }, connection.transmissions.last)
    assert_empty pubsub.stream_orderings
  end

  private
    def subscribe(ids: {}, supports_history: true)
      pubsub = Pubsub.new(ids:, supports_history:)
      connection = Connection.new(pubsub)
      channel = Channel.new(connection, identifier)
      channel.subscribe_to_channel

      subscriptions = ActionCable::Connection::Subscriptions.new(connection)
      subscriptions.execute_command "command" => "subscribe", "identifier" => identifier

      [ Channel.subscriber, connection, pubsub, subscriptions ]
    end

    def request_history(subscriptions, broadcasting, id)
      subscriptions.execute_command \
        "command" => "history", "identifier" => identifier, "broadcasting" => broadcasting, "id" => id
    end

    def identifier
      '{"channel":"ChronoCable::ChannelStreamsTest::Channel"}'
    end
end
