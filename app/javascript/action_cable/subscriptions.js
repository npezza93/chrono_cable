import logger from "./logger"
import Subscription from "./subscription"
import SubscriptionGuarantor from "./subscription_guarantor"

// Collection class for creating (and internally managing) channel subscriptions.
// The only method intended to be triggered by the user is ActionCable.Subscriptions#create,
// and it should be called through the consumer like so:
//
//   App = {}
//   App.cable = ActionCable.createConsumer("ws://example.com/accounts/1")
//   App.appearance = App.cable.subscriptions.create("AppearanceChannel")
//
// For more details on how you'd configure an actual channel subscription, see ActionCable.Subscription.

export default class Subscriptions {
  constructor(consumer) {
    this.consumer = consumer
    this.guarantor = new SubscriptionGuarantor(this)
    this.subscriptions = []
  }

  create(channelName, mixin) {
    const channel = channelName
    const params = typeof channel === "object" ? channel : {channel}
    const subscription = new Subscription(this.consumer, params, mixin)
    return this.add(subscription)
  }

  // Private

  add(subscription) {
    this.subscriptions.push(subscription)
    this.consumer.ensureActiveConnection()
    this.notify(subscription, "initialized")
    this.subscribe(subscription)
    return subscription
  }

  remove(subscription) {
    this.forget(subscription)
    if (!this.findAll(subscription.identifier).length) {
      this.sendCommand(subscription, "unsubscribe")
    }
    return subscription
  }

  reject(identifier) {
    return this.findAll(identifier).map((subscription) => {
      this.forget(subscription)
      this.notify(subscription, "rejected")
      return subscription
    })
  }

  forget(subscription) {
    this.guarantor.forget(subscription)
    subscription.reset()
    this.subscriptions = (this.subscriptions.filter((s) => s !== subscription))
    return subscription
  }

  findAll(identifier) {
    return this.subscriptions.filter((s) => s.identifier === identifier)
  }

  reload() {
    return this.subscriptions.map((subscription) =>
      this.subscribe(subscription))
  }

  notifyAll(callbackName, ...args) {
    return this.subscriptions.map((subscription) =>
      this.notify(subscription, callbackName, ...args))
  }

  notify(subscription, callbackName, ...args) {
    let subscriptions
    if (typeof subscription === "string") {
      subscriptions = this.findAll(subscription)
    } else {
      subscriptions = [subscription]
    }

    return subscriptions.map((subscription) =>
      (typeof subscription[callbackName] === "function" ? subscription[callbackName](...args) : undefined))
  }

  subscribe(subscription) {
    if (this.sendCommand(subscription, "subscribe")) {
      this.guarantor.guarantee(subscription)
    }
  }

  confirmSubscription(identifier, ids) {
    logger.log(`Subscription confirmed ${identifier}`)
    this.findAll(identifier).map((subscription) => {
      if (ids != null) {
        Object.entries(ids).forEach(([broadcasting, id]) => {
          const stream = subscription.findOrCreateStream(broadcasting, id)

          if (stream.isBehind(id)) {
            stream.restartRecovery(this)
          }
        })
      }
      this.guarantor.forget(subscription)
    })
  }

  sendCommand(subscription, command, data = {}) {
    const {identifier} = subscription
    return this.consumer.send({command, identifier, ...data})
  }

  receive(identifier, message, id, broadcasting) {
    if (id == null || broadcasting == null) {
      return this.notify(identifier, "received", message)
    } else {
      return this.findAll(identifier).map((subscription) => {
        const stream = subscription.findOrCreateStream(broadcasting)
        const receive = (message) => this.notify(subscription, "received", message)

        const processed = stream.processMessage(id, message, receive)

        if (processed) {
          stream.processQueue(receive)
          return subscription
        } else {
          return stream.recover(this, id, message)
        }
      })
    }
  }

  ingestHistory(identifier, broadcasting, {messages = [], earliest_id, id}) {
    return this.findAll(identifier).map((subscription) => {
      const stream = subscription.findOrCreateStream(broadcasting, id)

      stream.processMessages(messages, (message) => {
        this.notify(subscription, "received", message)
      }, earliest_id)

      return subscription
    })
  }
}
