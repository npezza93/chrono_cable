import { createConsumer as createActionCableConsumer } from "../action_cable"
let consumer

export async function getConsumer() {
  return consumer || setConsumer(createConsumer().then(setConsumer))
}

export function setConsumer(newConsumer) {
  return consumer = newConsumer
}

export async function createConsumer(...args) {
  return createActionCableConsumer(...args)
}

export async function subscribeTo(channel, mixin) {
  const { subscriptions } = await getConsumer()
  return subscriptions.create(channel, mixin)
}
