export default class Stream {
  constructor(subscription, broadcasting, id) {
    this.subscription = subscription
    this.broadcasting = broadcasting
    this.id = id
    this.recovering = false
    this.queue = []
  }

  increment(id) {
    this.id = id
  }

  messageWasProcessed(id) {
    return this.id != null && id <= this.id
  }

  messageIsProcessable(id) {
    return this.id == null || id === this.id + 1
  }

  caughtUp() {
    this.recovering = false
  }

  recover(subscriptions, id, message) {
    this.queue.push({id, message})

    if (!this.recovering) {
      this.recovering = true
      subscriptions.sendCommand(this.subscription, "history",
        {broadcasting: this.broadcasting, id: this.id})
    }
  }

  processMessage(id, payload, callback) {
    if (this.messageWasProcessed(id)) return true

    if (this.messageIsProcessable(id)) {
      this.increment(id)
      callback(payload)
      return true
    } else {
      return false
    }
  }

  processMessages(messages, callback) {
    messages
      .sort((a, b) => a.id - b.id)
      .forEach(({ id, payload }) => {
        this.processMessage(id, JSON.parse(payload), callback)
      })

    this.caughtUp()
    this.processQueue(callback)

    return this.subscription
  }

  processQueue(callback) {
    const remaining = []

    this.queue
      .sort((a, b) => a.id - b.id)
      .filter(({id}) => id > this.id)
      .forEach(({ id, message }) => {
        if (!this.processMessage(id, message, callback)) remaining.push({id, message})
      })

    this.queue = remaining
  }
}
