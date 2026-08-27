# ChronoCable

ChronoCable adds ordered, recoverable Action Cable streams backed by Solid Cable.
Every broadcast sent through Action Cable's Solid Cable adapter receives a
per-broadcasting sequence number. The default browser stream handler tracks those
numbers, detects gaps, requests the missing messages, and delivers them to the
subscription in order. The same behavior applies to Turbo Streams without changing
application code.

ChronoCable requires Rails 8.2 or newer and Solid Cable 4.1 or newer.

## How it works

When Action Cable broadcasts a message, ChronoCable:

1. Locks a database record for that broadcasting and assigns its next ID.
2. Passes the numbered message to Solid Cable's batched broadcaster.
3. Persists the batch with each message's broadcasting-specific ID.
4. Sends the ID and broadcasting name alongside the normal Action Cable payload.

The ChronoCable client keeps the last processed ID for each default stream. If it
receives a later ID than expected, it queues that message and asks the server for
history after its last processed ID. Retained messages are replayed in order before
the queued live messages are delivered.

On initial subscription, the server reports the highest ID already persisted for
each stream. On reconnection, the client keeps its previous position and requests
anything persisted while it was disconnected.

Sequence numbers are independent for each broadcasting. There is no global order
between different broadcastings.

## Installation

Add ChronoCable to the application:

```ruby
gem "chrono_cable"
```

Install the bundle, run the generator, and migrate:

```bash
bundle install
bin/rails generate chrono_cable:install
bin/rails db:migrate
```

The generator:

- Creates `solid_cable_channels`, which stores the current ID for each
  broadcasting.
- Adds `channel_id` and a unique per-broadcasting index to
  `solid_cable_messages`.
- Replaces the standard Action Cable and Turbo importmap pins with ChronoCable's
  prebuilt browser bundles when `config/importmap.rb` is present.

The ChronoCable migrations must be deployed before the new application code begins
broadcasting. Messages written before `channel_id` was added are left unnumbered
and are not part of replayable history.

### Importmap

For a standard Rails importmap application, the generator changes these pins:

```ruby
pin "@rails/actioncable", to: "chronocable.js"
pin "@hotwired/turbo-rails", to: "chronocable_turbo.min.js"
```

If the application has customized or differently formatted pins, make the same
replacement manually. Applications that do not use Turbo only need the Action
Cable replacement.

### Custom stream callbacks

A stream with a custom callback or block remains replayable:

```ruby
stream_from "metrics", coder: ActiveSupport::JSON do |message|
  record_metric message
end
```

When history is requested, ChronoCable decodes each retained message and runs it
through the stream's callback in sequence. Historical callback invocations do not
automatically transmit the original payload to the browser.

## Guarantees and limitations

- Ordering and gap detection are per broadcasting.
- IDs are assigned synchronously under a database row lock; message inserts remain
  batched by Solid Cable.
- Replay is limited to messages still retained by Solid Cable. If older messages
  have been trimmed, the client advances to the earliest available ID and resumes.
- A process crash after an ID is reserved but before its in-memory batch is
  persisted can leave a permanent gap. Database-backed sequence assignment and an
  in-memory batch cannot be committed atomically.
- A history request currently returns every retained message after the requested
  ID in one response. Set Solid Cable's message retention with that upper bound in
  mind.
- Historical messages for custom streams are replayed through their server-side
  callbacks rather than transmitted directly to the browser.

## Development

Run the test suite and style checks with:

```bash
bin/rails test
bundle exec rubocop
```
## Contributing

Bug reports and pull requests are welcome at
[github.com/npezza93/chrono_cable](https://github.com/npezza93/chrono_cable).

## License

ChronoCable is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
