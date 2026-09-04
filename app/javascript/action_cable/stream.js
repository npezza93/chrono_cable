export default class Stream {
  constructor(subscription, broadcasting, id) {
    this.subscription = subscription
    this.broadcasting = broadcasting
    this.id = id
    this.recovering = false
    this.queue = []
  }

  isBehind(id) {
    return this.id != null && this.id < id
  }

  recover(subscriptions, id, message) {
    this.queue.push({id, message})
    this.requestHistory(subscriptions)
  }

  requestHistory(subscriptions) {
    if (!this.recovering) {
      this.recovering = true
      subscriptions.sendCommand(this.subscription, "history",
        {broadcasting: this.broadcasting, id: this.id})
    }
  }

  restartRecovery(subscriptions) {
    this.recovering = false
    this.requestHistory(subscriptions)
  }

  processMessage(id, payload, callback) {
    if (this.id != null && id <= this.id) return true

    if (this.id == null || id === this.id + 1) {
      this.id = id
      callback(payload)
      return true
    }

    return false
  }

  processMessages(messages, callback) {
    const history = messages.map(({ id, payload }) => ({ id, message: JSON.parse(payload) }))
    this.queue = history.concat(this.queue)

    this.queue.sort((a, b) => a.id - b.id).forEach(({ id, message }) => {
      if (this.id == null || id > this.id) {
        this.id = id
        callback(message)
      }
    })

    this.queue = []
    this.recovering = false

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
