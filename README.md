# ChronoCable

ChronoCable adds opt-in ordering and gap recovery to Action Cable streams backed by Solid Cable.

## Installation

Add the gem:

```ruby
gem "chrono_cable"
```

Then install it:

```bash
bundle install
bin/rails generate chrono_cable:install
bin/rails db:prepare
```

The generator adds sequence storage and, in importmap apps, replaces the Action Cable and Turbo pins with ChronoCable's browser bundles.

Your importmap should look like:

```ruby
pin "@rails/actioncable", to: "chronocable.js"
pin "@hotwired/turbo-rails", to: "chronocable_turbo.min.js"
```

Apps without Turbo only need the Action Cable pin.

## Usage

Enable ordered delivery per broadcasting:

```ruby
stream_from "metrics", deliver_in_order: true
```

For Turbo Streams, pass the option through a data attribute:

```erb
<%= turbo_stream_from "metrics", data: { deliver_in_order: true } %>
```

ChronoCable assigns sequence numbers per broadcasting. The browser queues out-of-order messages, replays retained history, and resumes after the last delivered message on reconnect. History is authoritative, so missing or trimmed sequence numbers are skipped.

Streams are unordered by default.

### Custom callbacks

```ruby
stream_from "metrics", deliver_in_order: true do |message|
  transmit message
end
```

Historical messages are passed through the callback. The callback is responsible for transmitting them when appropriate.

## Development

```bash
bin/rails test
bun run test
bundle exec rubocop
bun run build
```

Bug reports and pull requests are welcome. ChronoCable is released under the [MIT License](https://opensource.org/licenses/MIT).
