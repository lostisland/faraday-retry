---
name: Bug report
about: Create a report to help us improve
title: ''
labels: ''
assignees: ''

---

### Basic Version Info
Faraday Version: X.Y.Z
Ruby Version: X.Y.Z

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
  gem "faraday-retry"
end

count = 0
expected = 5
retry_options = {
  max: expected,
  interval: 0.1,
  retry_statuses: [503],
  retry_block: proc { count += 1 }
}

faraday = Faraday.new do |conn|
  conn.request :retry, **retry_options
end

faraday.get("https://httpbin.org/status/503")

exit 0 if count == expected

warn "Retried #{count} times, expected #{expected}"
exit 1
```
