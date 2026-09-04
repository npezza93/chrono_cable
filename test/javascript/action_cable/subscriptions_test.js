import { describe, expect, test } from "bun:test"
import Subscription from "../../../app/javascript/action_cable/subscription"
import Subscriptions from "../../../app/javascript/action_cable/subscriptions"

const buildSubscriptions = (receivedBySubscription = [[], []]) => {
  const commands = []
  const consumer = { send: (command) => commands.push(command) }
  const subscriptions = new Subscriptions(consumer)

  subscriptions.subscriptions = receivedBySubscription.map((received) =>
    new Subscription(consumer, { channel: "MessagesChannel" }, {
      received: (message) => received.push(message)
    })
  )

  return { commands, subscriptions }
}

describe("Subscriptions", () => {
  test("delivers live and historical messages once to each matching subscription", () => {
    const received = [[], []]
    const { subscriptions } = buildSubscriptions(received)
    const identifier = subscriptions.subscriptions[0].identifier

    subscriptions.receive(identifier, "hello", 1, "messages")
    subscriptions.ingestHistory(identifier, "messages", {
      messages: [{ id: 2, payload: JSON.stringify("history") }]
    })

    expect(received).toEqual([["hello", "history"], ["hello", "history"]])
  })

  test("drains queued messages when a delayed live message closes the gap", () => {
    const received = [[]]
    const { commands, subscriptions } = buildSubscriptions(received)
    const subscription = subscriptions.subscriptions[0]
    const stream = subscription.findOrCreateStream("messages", 0)

    subscriptions.receive(subscription.identifier, "second", 2, "messages")
    subscriptions.receive(subscription.identifier, "first", 1, "messages")

    expect(received[0]).toEqual(["first", "second"])
    expect(stream.queue).toEqual([])
    expect(commands).toEqual([{
      command: "history",
      identifier: subscription.identifier,
      broadcasting: "messages",
      id: 0
    }])
  })

  test("recovers from a confirmed id and skips gaps missing from history", () => {
    const received = [[]]
    const { commands, subscriptions } = buildSubscriptions(received)
    const subscription = subscriptions.subscriptions[0]

    subscriptions.confirmSubscription(subscription.identifier, { messages: 3 })
    subscriptions.receive(subscription.identifier, "fifth", 5, "messages")
    subscriptions.ingestHistory(subscription.identifier, "messages", {
      messages: [
        { id: 5, payload: JSON.stringify("fifth") }
      ]
    })
    subscriptions.receive(subscription.identifier, "late fourth", 4, "messages")

    expect(received[0]).toEqual(["fifth"])
    expect(commands).toEqual([{
      command: "history",
      identifier: subscription.identifier,
      broadcasting: "messages",
      id: 3
    }])
  })

  test("drains queued messages when history is empty", () => {
    const received = [[]]
    const { subscriptions } = buildSubscriptions(received)
    const subscription = subscriptions.subscriptions[0]
    const stream = subscription.findOrCreateStream("messages", 2)

    subscriptions.receive(subscription.identifier, "fourth", 4, "messages")
    subscriptions.ingestHistory(subscription.identifier, "messages", { messages: [] })

    expect(received[0]).toEqual(["fourth"])
    expect(stream.id).toBe(4)
    expect(stream.queue).toEqual([])
  })
})
