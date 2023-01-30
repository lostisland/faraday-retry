### Basic Version Info
Faraday Version: 1.7.1 (and also main branch at fdf797b)
Ruby Version: 2.7.4

### Issue description

<!-- Tell us what's wrong -->

### Actual behavior
<!-- Tell us what should happen -->

### Expected behavior
<!-- Tell us what should happen -->

### Steps to reproduce

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"
gemfile do
  source "https://rubygems.org"

  gem "faraday"
  gem "typhoeus"
end

count = 0
expected = 5

faraday = Faraday.new do |conn|
  retry_options = {
    max: expected,
    interval: 0.1,
    retry_statuses: [503],
    retry_block: proc { count += 1 }
  }
  conn.request :retry, **retry_options
  conn.adapter :typhoeus
end

faraday.in_parallel do
  faraday.get("https://httpbin.org/status/503")
end

exit 0 if count == expected

warn "Retried #{count} times, expected #{expected}"
exit 1
```
