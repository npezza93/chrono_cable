// app/javascript/action_cable/adapters.js
var adapters_default = {
  logger: typeof console !== "undefined" ? console : undefined,
  WebSocket: typeof WebSocket !== "undefined" ? WebSocket : undefined
};

// app/javascript/action_cable/logger.js
var logger_default = {
  log(...messages) {
    if (this.enabled) {
      messages.push(Date.now());
      adapters_default.logger.log("[ActionCable]", ...messages);
    }
  }
};

// app/javascript/action_cable/connection_monitor.js
var now = () => new Date().getTime();
var secondsSince = (time) => (now() - time) / 1000;

class ConnectionMonitor {
  constructor(connection) {
    this.visibilityDidChange = this.visibilityDidChange.bind(this);
    this.connection = connection;
    this.reconnectAttempts = 0;
  }
  start() {
    if (!this.isRunning()) {
      this.startedAt = now();
      delete this.stoppedAt;
      this.startPolling();
      addEventListener("visibilitychange", this.visibilityDidChange);
      logger_default.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`);
    }
  }
  stop() {
    if (this.isRunning()) {
      this.stoppedAt = now();
      this.stopPolling();
      removeEventListener("visibilitychange", this.visibilityDidChange);
      logger_default.log("ConnectionMonitor stopped");
    }
  }
  isRunning() {
    return this.startedAt && !this.stoppedAt;
  }
  recordMessage() {
    this.pingedAt = now();
  }
  recordConnect() {
    this.reconnectAttempts = 0;
    delete this.disconnectedAt;
    logger_default.log("ConnectionMonitor recorded connect");
  }
  recordDisconnect() {
    this.disconnectedAt = now();
    logger_default.log("ConnectionMonitor recorded disconnect");
  }
  startPolling() {
    this.stopPolling();
    this.poll();
  }
  stopPolling() {
    clearTimeout(this.pollTimeout);
  }
  poll() {
    this.pollTimeout = setTimeout(() => {
      this.reconnectIfStale();
      this.poll();
    }, this.getPollInterval());
  }
  getPollInterval() {
    const { staleThreshold, reconnectionBackoffRate } = this.constructor;
    const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10));
    const jitterMax = this.reconnectAttempts === 0 ? 1 : reconnectionBackoffRate;
    const jitter = jitterMax * Math.random();
    return staleThreshold * 1000 * backoff * (1 + jitter);
  }
  reconnectIfStale() {
    if (this.connectionIsStale()) {
      logger_default.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
      this.reconnectAttempts++;
      if (this.disconnectedRecently()) {
        logger_default.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince(this.disconnectedAt)} s`);
      } else {
        logger_default.log("ConnectionMonitor reopening");
        this.connection.reopen();
      }
    }
  }
  get refreshedAt() {
    return this.pingedAt ? this.pingedAt : this.startedAt;
  }
  connectionIsStale() {
    return secondsSince(this.refreshedAt) > this.constructor.staleThreshold;
  }
  disconnectedRecently() {
    return this.disconnectedAt && secondsSince(this.disconnectedAt) < this.constructor.staleThreshold;
  }
  visibilityDidChange() {
    if (document.visibilityState === "visible") {
      setTimeout(() => {
        if (this.connectionIsStale() || !this.connection.isOpen()) {
          logger_default.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`);
          this.connection.reopen();
        }
      }, 200);
    }
  }
}
ConnectionMonitor.staleThreshold = 6;
ConnectionMonitor.reconnectionBackoffRate = 0.15;
var connection_monitor_default = ConnectionMonitor;

// app/javascript/action_cable/internal.js
var internal_default = {
  message_types: {
    welcome: "welcome",
    disconnect: "disconnect",
    ping: "ping",
    history: "history",
    confirmation: "confirm_subscription",
    rejection: "reject_subscription"
  },
  disconnect_reasons: {
    unauthorized: "unauthorized",
    invalid_request: "invalid_request",
    server_restart: "server_restart",
    remote: "remote"
  },
  default_mount_path: "/cable",
  protocols: [
    "actioncable-v1-json",
    "actioncable-unsupported"
  ]
};

// app/javascript/action_cable/connection.js
var { message_types, protocols } = internal_default;
var supportedProtocols = protocols.slice(0, protocols.length - 1);
var indexOf = [].indexOf;

class Connection {
  constructor(consumer) {
    this.open = this.open.bind(this);
    this.consumer = consumer;
    this.subscriptions = this.consumer.subscriptions;
    this.monitor = new connection_monitor_default(this);
    this.disconnected = true;
  }
  send(data) {
    if (this.isOpen()) {
      this.webSocket.send(JSON.stringify(data));
      return true;
    } else {
      return false;
    }
  }
  open() {
    if (this.isActive()) {
      logger_default.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
      return false;
    } else {
      const socketProtocols = [...protocols, ...this.consumer.subprotocols || []];
      logger_default.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${socketProtocols}`);
      if (this.webSocket) {
        this.uninstallEventHandlers();
      }
      this.webSocket = new adapters_default.WebSocket(this.consumer.url, socketProtocols);
      this.installEventHandlers();
      this.monitor.start();
      return true;
    }
  }
  close({ allowReconnect } = { allowReconnect: true }) {
    if (!allowReconnect) {
      this.monitor.stop();
    }
    if (this.isOpen()) {
      return this.webSocket.close();
    }
  }
  reopen() {
    logger_default.log(`Reopening WebSocket, current state is ${this.getState()}`);
    if (this.isActive()) {
      try {
        return this.close();
      } catch (error) {
        logger_default.log("Failed to reopen WebSocket", error);
      } finally {
        logger_default.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
        setTimeout(this.open, this.constructor.reopenDelay);
      }
    } else {
      return this.open();
    }
  }
  getProtocol() {
    if (this.webSocket) {
      return this.webSocket.protocol;
    }
  }
  isOpen() {
    return this.isState("open");
  }
  isActive() {
    return this.isState("open", "connecting");
  }
  triedToReconnect() {
    return this.monitor.reconnectAttempts > 0;
  }
  isProtocolSupported() {
    return indexOf.call(supportedProtocols, this.getProtocol()) >= 0;
  }
  isState(...states) {
    return indexOf.call(states, this.getState()) >= 0;
  }
  getState() {
    if (this.webSocket) {
      for (let state in adapters_default.WebSocket) {
        if (adapters_default.WebSocket[state] === this.webSocket.readyState) {
          return state.toLowerCase();
        }
      }
    }
    return null;
  }
  installEventHandlers() {
    for (let eventName in this.events) {
      const handler = this.events[eventName].bind(this);
      this.webSocket[`on${eventName}`] = handler;
    }
  }
  uninstallEventHandlers() {
    for (let eventName in this.events) {
      this.webSocket[`on${eventName}`] = function() {};
    }
  }
}
Connection.reopenDelay = 500;
Connection.prototype.events = {
  message(event) {
    if (!this.isProtocolSupported()) {
      return;
    }
    const { identifier, ids, message, reason, reconnect, type, broadcasting, id } = JSON.parse(event.data);
    this.monitor.recordMessage();
    switch (type) {
      case message_types.welcome:
        if (this.triedToReconnect()) {
          this.reconnectAttempted = true;
        }
        this.monitor.recordConnect();
        return this.subscriptions.reload();
      case message_types.disconnect:
        logger_default.log(`Disconnecting. Reason: ${reason}`);
        return this.close({ allowReconnect: reconnect });
      case message_types.history:
        return this.subscriptions.ingestHistory(identifier, broadcasting, message);
      case message_types.ping:
        return null;
      case message_types.confirmation:
        this.subscriptions.confirmSubscription(identifier, ids);
        if (this.reconnectAttempted) {
          this.reconnectAttempted = false;
          return this.subscriptions.notify(identifier, "connected", { reconnected: true });
        } else {
          return this.subscriptions.notify(identifier, "connected", { reconnected: false });
        }
      case message_types.rejection:
        return this.subscriptions.reject(identifier);
      default:
        return this.subscriptions.receive(identifier, message, id, broadcasting);
    }
  },
  open() {
    logger_default.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
    this.disconnected = false;
    if (!this.isProtocolSupported()) {
      logger_default.log("Protocol is unsupported. Stopping monitor and disconnecting.");
      return this.close({ allowReconnect: false });
    }
  },
  close(event) {
    logger_default.log("WebSocket onclose event");
    if (this.disconnected) {
      return;
    }
    this.disconnected = true;
    this.monitor.recordDisconnect();
    return this.subscriptions.notifyAll("disconnected", { willAttemptReconnect: this.monitor.isRunning() });
  },
  error() {
    logger_default.log("WebSocket onerror event");
  }
};
var connection_default = Connection;

// app/javascript/action_cable/stream.js
class Stream {
  constructor(subscription, broadcasting, id) {
    this.subscription = subscription;
    this.broadcasting = broadcasting;
    this.id = id;
    this.recovering = false;
    this.queue = [];
  }
  increment(id) {
    this.id = id;
  }
  messageWasProcessed(id) {
    return this.id != null && id <= this.id;
  }
  messageIsProcessable(id) {
    return this.id == null || id === this.id + 1;
  }
  isBehind(id) {
    return this.id != null && this.id < id;
  }
  jumpToEarliestAvailableId(earliestId) {
    if (this.id != null && earliestId != null && earliestId > this.id + 1) {
      this.id = earliestId - 1;
    }
  }
  skipMissingIdsBefore(id) {
    if (this.isBehind(id) && !this.messageIsProcessable(id)) {
      this.id = id - 1;
    }
  }
  caughtUp() {
    this.recovering = false;
  }
  recover(subscriptions, id, message) {
    this.queue.push({ id, message });
    this.requestHistory(subscriptions);
  }
  requestHistory(subscriptions) {
    if (!this.recovering) {
      this.recovering = true;
      subscriptions.sendCommand(this.subscription, "history", { broadcasting: this.broadcasting, id: this.id });
    }
  }
  restartRecovery(subscriptions) {
    this.recovering = false;
    this.requestHistory(subscriptions);
  }
  processMessage(id, payload, callback) {
    if (this.messageWasProcessed(id))
      return true;
    if (this.messageIsProcessable(id)) {
      this.increment(id);
      callback(payload);
      return true;
    } else {
      return false;
    }
  }
  processMessages(messages, callback, earliestId) {
    this.jumpToEarliestAvailableId(earliestId);
    messages.sort((a, b) => a.id - b.id).forEach(({ id, payload }) => {
      this.skipMissingIdsBefore(id);
      this.processMessage(id, JSON.parse(payload), callback);
    });
    this.caughtUp();
    this.processQueue(callback);
    return this.subscription;
  }
  processQueue(callback) {
    const remaining = [];
    this.queue.sort((a, b) => a.id - b.id).filter(({ id }) => id > this.id).forEach(({ id, message }) => {
      if (!this.processMessage(id, message, callback))
        remaining.push({ id, message });
    });
    this.queue = remaining;
  }
}

// app/javascript/action_cable/subscription.js
var extend = function(object, properties) {
  if (properties != null) {
    for (let key in properties) {
      const value = properties[key];
      object[key] = value;
    }
  }
  return object;
};

class Subscription {
  constructor(consumer, params = {}, mixin) {
    this.consumer = consumer;
    this.identifier = JSON.stringify(params);
    this.streams = {};
    extend(this, mixin);
  }
  perform(action, data = {}) {
    data.action = action;
    return this.send(data);
  }
  send(data) {
    return this.consumer.send({ command: "message", identifier: this.identifier, data: JSON.stringify(data) });
  }
  unsubscribe() {
    return this.consumer.subscriptions.remove(this);
  }
  reset() {
    this.streams = {};
  }
  findOrCreateStream(broadcasting, id = null) {
    if (this.streams[broadcasting] == null) {
      this.streams[broadcasting] = new Stream(this, broadcasting, id);
    }
    return this.streams[broadcasting];
  }
}

// app/javascript/action_cable/subscription_guarantor.js
class SubscriptionGuarantor {
  constructor(subscriptions) {
    this.subscriptions = subscriptions;
    this.pendingSubscriptions = [];
  }
  guarantee(subscription) {
    if (this.pendingSubscriptions.indexOf(subscription) == -1) {
      logger_default.log(`SubscriptionGuarantor guaranteeing ${subscription.identifier}`);
      this.pendingSubscriptions.push(subscription);
    } else {
      logger_default.log(`SubscriptionGuarantor already guaranteeing ${subscription.identifier}`);
    }
    this.startGuaranteeing();
  }
  forget(subscription) {
    logger_default.log(`SubscriptionGuarantor forgetting ${subscription.identifier}`);
    this.pendingSubscriptions = this.pendingSubscriptions.filter((s) => s !== subscription);
  }
  startGuaranteeing() {
    this.stopGuaranteeing();
    this.retrySubscribing();
  }
  stopGuaranteeing() {
    clearTimeout(this.retryTimeout);
  }
  retrySubscribing() {
    this.retryTimeout = setTimeout(() => {
      if (this.subscriptions && typeof this.subscriptions.subscribe === "function") {
        this.pendingSubscriptions.map((subscription) => {
          logger_default.log(`SubscriptionGuarantor resubscribing ${subscription.identifier}`);
          this.subscriptions.subscribe(subscription);
        });
      }
    }, 500);
  }
}
var subscription_guarantor_default = SubscriptionGuarantor;

// app/javascript/action_cable/subscriptions.js
class Subscriptions {
  constructor(consumer) {
    this.consumer = consumer;
    this.guarantor = new subscription_guarantor_default(this);
    this.subscriptions = [];
  }
  create(channelName, mixin) {
    const channel = channelName;
    const params = typeof channel === "object" ? channel : { channel };
    const subscription = new Subscription(this.consumer, params, mixin);
    return this.add(subscription);
  }
  add(subscription) {
    this.subscriptions.push(subscription);
    this.consumer.ensureActiveConnection();
    this.notify(subscription, "initialized");
    this.subscribe(subscription);
    return subscription;
  }
  remove(subscription) {
    this.forget(subscription);
    if (!this.findAll(subscription.identifier).length) {
      this.sendCommand(subscription, "unsubscribe");
    }
    return subscription;
  }
  reject(identifier) {
    return this.findAll(identifier).map((subscription) => {
      this.forget(subscription);
      this.notify(subscription, "rejected");
      return subscription;
    });
  }
  forget(subscription) {
    this.guarantor.forget(subscription);
    subscription.reset();
    this.subscriptions = this.subscriptions.filter((s) => s !== subscription);
    return subscription;
  }
  findAll(identifier) {
    return this.subscriptions.filter((s) => s.identifier === identifier);
  }
  reload() {
    return this.subscriptions.map((subscription) => this.subscribe(subscription));
  }
  notifyAll(callbackName, ...args) {
    return this.subscriptions.map((subscription) => this.notify(subscription, callbackName, ...args));
  }
  notify(subscription, callbackName, ...args) {
    let subscriptions;
    if (typeof subscription === "string") {
      subscriptions = this.findAll(subscription);
    } else {
      subscriptions = [subscription];
    }
    return subscriptions.map((subscription2) => typeof subscription2[callbackName] === "function" ? subscription2[callbackName](...args) : undefined);
  }
  subscribe(subscription) {
    if (this.sendCommand(subscription, "subscribe")) {
      this.guarantor.guarantee(subscription);
    }
  }
  confirmSubscription(identifier, ids) {
    logger_default.log(`Subscription confirmed ${identifier}`);
    this.findAll(identifier).map((subscription) => {
      if (ids != null) {
        Object.entries(ids).forEach(([broadcasting, id]) => {
          const stream = subscription.findOrCreateStream(broadcasting, id);
          if (stream.isBehind(id)) {
            stream.restartRecovery(this);
          }
        });
      }
      this.guarantor.forget(subscription);
    });
  }
  sendCommand(subscription, command, data = {}) {
    const { identifier } = subscription;
    return this.consumer.send({ command, identifier, ...data });
  }
  receive(identifier, message, id, broadcasting) {
    if (id == null || broadcasting == null) {
      return this.notify(identifier, "received", message);
    } else {
      return this.findAll(identifier).map((subscription) => {
        const stream = subscription.findOrCreateStream(broadcasting);
        const receive = (message2) => this.notify(subscription, "received", message2);
        const processed = stream.processMessage(id, message, receive);
        if (processed) {
          stream.processQueue(receive);
          return subscription;
        } else {
          return stream.recover(this, id, message);
        }
      });
    }
  }
  ingestHistory(identifier, broadcasting, { messages = [], earliest_id, id }) {
    return this.findAll(identifier).map((subscription) => {
      const stream = subscription.findOrCreateStream(broadcasting, id);
      stream.processMessages(messages, (message) => {
        this.notify(subscription, "received", message);
      }, earliest_id);
      return subscription;
    });
  }
}

// app/javascript/action_cable/consumer.js
class Consumer {
  constructor(url) {
    this._url = url;
    this.subscriptions = new Subscriptions(this);
    this.connection = new connection_default(this);
    this.subprotocols = [];
  }
  get url() {
    return createWebSocketURL(this._url);
  }
  send(data) {
    return this.connection.send(data);
  }
  connect() {
    return this.connection.open();
  }
  disconnect() {
    return this.connection.close({ allowReconnect: false });
  }
  ensureActiveConnection() {
    if (!this.connection.isActive()) {
      return this.connection.open();
    }
  }
  addSubProtocol(subprotocol) {
    this.subprotocols = [...this.subprotocols, subprotocol];
  }
}
function createWebSocketURL(url) {
  if (typeof url === "function") {
    url = url();
  }
  if (url && !/^wss?:/i.test(url)) {
    const a = document.createElement("a");
    a.href = url;
    a.href = a.href;
    a.protocol = a.protocol.replace("http", "ws");
    return a.href;
  } else {
    return url;
  }
}

// app/javascript/action_cable/index.js
function createConsumer(url = getConfig("url") || internal_default.default_mount_path) {
  return new Consumer(url);
}
function getConfig(name) {
  const element = document.head.querySelector(`meta[name='action-cable-${name}']`);
  if (element) {
    return element.getAttribute("content");
  }
}
export {
  connection_default as Connection,
  connection_monitor_default as ConnectionMonitor,
  Consumer,
  internal_default as INTERNAL,
  Subscription,
  subscription_guarantor_default as SubscriptionGuarantor,
  Subscriptions,
  adapters_default as adapters,
  createConsumer,
  createWebSocketURL,
  getConfig,
  logger_default as logger
};
