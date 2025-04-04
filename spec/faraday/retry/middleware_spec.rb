# frozen_string_literal: true

RSpec.describe Faraday::Retry::Middleware do
  let(:calls) { [] }
  let(:times_called) { calls.size }
  let(:options) { [] }
  let(:conn) do
    Faraday.new do |b|
      b.request :retry, *options

      b.adapter :test do |stub|
        %w[get post].each do |method|
          stub.send(method, '/unstable') do |env|
            calls << env.dup
            env[:body] = nil # simulate blanking out response body
            callback.call
          end
        end
      end
    end
  end

  context 'when an unexpected error happens' do
    let(:callback) { -> { raise 'boom!' } }

    before { expect { conn.get('/unstable') }.to raise_error(RuntimeError) }

    it { expect(times_called).to eq(1) }

    context 'when this is passed as a custom exception' do
      let(:options) { [{ exceptions: StandardError }] }

      it { expect(times_called).to eq(3) }
    end

    context 'when this is passed as a string custom exception' do
      let(:options) { [{ exceptions: 'StandardError' }] }

      it { expect(times_called).to eq(3) }
    end

    context 'when a non-existent string custom exception is passed' do
      let(:options) { [{ exceptions: 'WrongStandardErrorNotExisting' }] }

      it { expect(times_called).to eq(1) }
    end
  end

  context 'when an expected error happens' do
    let(:callback) { -> { raise Errno::ETIMEDOUT } }

    before do
      @started = Time.now
      expect { conn.get('/unstable') }.to raise_error(Errno::ETIMEDOUT)
    end

    it { expect(times_called).to eq(3) }

    context 'when legacy max_retry set to 1' do
      let(:options) { [1] }

      it { expect(times_called).to eq(2) }
    end

    context 'when legacy max_retry set to -9' do
      let(:options) { [-9] }

      it { expect(times_called).to eq(1) }
    end

    context 'when new max_retry set to 3' do
      let(:options) { [{ max: 3 }] }

      it { expect(times_called).to eq(4) }
    end

    context 'when new max_retry set to -9' do
      let(:options) { [{ max: -9 }] }

      it { expect(times_called).to eq(1) }
    end

    context 'when both max_retry and interval are set' do
      let(:options) { [{ max: 2, interval: 0.1 }] }

      it { expect(Time.now - @started).to be_within(0.04).of(0.2) }
    end

    context 'when retry_block is set' do
      let(:options) { [{ retry_block: ->(**kwargs) { retry_block_calls << kwargs } }] }
      let(:retry_block_calls) { [] }
      let(:retry_block_times_called) { retry_block_calls.size }

      it 'calls retry block for each retry' do
        expect(retry_block_times_called).to eq(2)
      end

      describe 'with arguments to retry_block' do
        it { expect(retry_block_calls.first[:exception]).to be_kind_of(Errno::ETIMEDOUT) }
        it { expect(retry_block_calls.first[:options]).to be_kind_of(Faraday::Options) }
        it { expect(retry_block_calls.first[:env]).to be_kind_of(Faraday::Env) }
        it { expect(retry_block_calls.first[:retry_count]).to be_kind_of(Integer) }
        it { expect(retry_block_calls.first[:retry_count]).to eq 0 }
      end

      describe 'arguments to retry_block on second call' do
        it { expect(retry_block_calls[1][:retry_count]).to eq 1 }
      end
    end

    context 'when exhausted_retries_block is set' do
      let(:numbers) { [] }

      # The required arguments are env, exception and options, but we may add more, if we supply a default value.
      let(:logic) { ->(number: 1, **) { numbers.push(number) } }
      let(:options) do
        [
          {
            exhausted_retries_block: logic,
            max: 2
          }
        ]
      end

      describe 'with arguments to exhausted_retries_block' do
        let(:exhausted_retries_block_calls) { [] }
        let(:options) { [{ exhausted_retries_block: ->(**kwargs) { exhausted_retries_block_calls << kwargs } }] }

        it { expect(exhausted_retries_block_calls.first[:exception]).to be_kind_of(Errno::ETIMEDOUT) }
        it { expect(exhausted_retries_block_calls.first[:options]).to be_kind_of(Faraday::Options) }
        it { expect(exhausted_retries_block_calls.first[:env]).to be_kind_of(Faraday::Env) }
      end

      it 'calls exhausted_retries_block block once when retries are exhausted' do
        expect(numbers).to eq([1])
      end

      it { expect(times_called).to eq(options.first[:max] + 1) }
    end
  end

  context 'when no exception raised' do
    let(:options) { [{ max: 1, retry_statuses: 429 }] }

    before { conn.get('/unstable') }

    context 'when response code is in retry_statuses' do
      let(:callback) { -> { [429, {}, ''] } }

      it { expect(times_called).to eq(2) }
    end

    context 'when response code is not in retry_statuses' do
      let(:callback) { -> { [503, {}, ''] } }

      it { expect(times_called).to eq(1) }
    end
  end

  describe '#calculate_retry_interval' do
    context 'with exponential backoff' do
      let(:options) { { max: 5, interval: 0.1, backoff_factor: 2 } }
      let(:middleware) { described_class.new(nil, options) }

      it { expect(middleware.send(:calculate_retry_interval, 5)).to eq(0.1) }
      it { expect(middleware.send(:calculate_retry_interval, 4)).to eq(0.2) }
      it { expect(middleware.send(:calculate_retry_interval, 3)).to eq(0.4) }
    end

    context 'with exponential backoff and max_interval' do
      let(:options) { { max: 5, interval: 0.1, backoff_factor: 2, max_interval: 0.3 } }
      let(:middleware) { described_class.new(nil, options) }

      it { expect(middleware.send(:calculate_retry_interval, 5)).to eq(0.1) }
      it { expect(middleware.send(:calculate_retry_interval, 4)).to eq(0.2) }
      it { expect(middleware.send(:calculate_retry_interval, 3)).to eq(0.3) }
      it { expect(middleware.send(:calculate_retry_interval, 2)).to eq(0.3) }
    end

    context 'with exponential backoff and interval_randomness' do
      let(:options) { { max: 2, interval: 0.1, interval_randomness: 0.05 } }
      let(:middleware) { described_class.new(nil, options) }

      it { expect(middleware.send(:calculate_retry_interval, 2)).to be_between(0.1, 0.105) }
    end
  end

  context 'when method is not idempotent' do
    let(:callback) { -> { raise Errno::ETIMEDOUT } }

    before { expect { conn.post('/unstable') }.to raise_error(Errno::ETIMEDOUT) }

    it { expect(times_called).to eq(1) }
  end

  describe 'retry_if option' do
    let(:callback) { -> { raise Errno::ETIMEDOUT } }
    let(:options) { [{ retry_if: @check }] }

    it 'retries if retry_if block always returns true' do
      body = { foo: :bar }
      @check = ->(_, _) { true }
      expect { conn.post('/unstable', body) }.to raise_error(Errno::ETIMEDOUT)
      expect(times_called).to eq(3)
      expect(calls).to(be_all { |env| env[:body] == body })
    end

    it 'does not retry if retry_if block returns false checking env' do
      @check = ->(env, _) { env[:method] != :post }
      expect { conn.post('/unstable') }.to raise_error(Errno::ETIMEDOUT)
      expect(times_called).to eq(1)
    end

    it 'does not retry if retry_if block returns false checking exception' do
      @check = ->(_, exception) { !exception.is_a?(Errno::ETIMEDOUT) }
      expect { conn.post('/unstable') }.to raise_error(Errno::ETIMEDOUT)
      expect(times_called).to eq(1)
    end

    it 'FilePart: should rewind files on retry' do
      io = StringIO.new('Test data')
      filepart = Faraday::Multipart::FilePart.new(io, 'application/octet/stream')

      rewound = 0
      rewind = -> { rewound += 1 }

      @check = ->(_, _) { true }
      allow(filepart).to receive(:rewind, &rewind)
      expect { conn.post('/unstable', file: filepart) }.to raise_error(Errno::ETIMEDOUT)
      expect(times_called).to eq(3)
      expect(rewound).to eq(2)
    end

    it 'UploadIO: should rewind files on retry' do
      io = StringIO.new('Test data')
      upload_io = Faraday::Multipart::FilePart.new(io, 'application/octet/stream')

      rewound = 0
      rewind = -> { rewound += 1 }

      @check = ->(_, _) { true }
      allow(upload_io).to receive(:rewind, &rewind)
      expect { conn.post('/unstable', file: upload_io) }.to raise_error(Errno::ETIMEDOUT)
      expect(times_called).to eq(3)
      expect(rewound).to eq(2)
    end

    context 'when explicitly specifying methods to retry' do
      let(:options) { [{ retry_if: @check, methods: [:post] }] }

      it 'does not call retry_if for specified methods' do
        @check = ->(_, _) { raise 'this should have never been called' }
        expect { conn.post('/unstable') }.to raise_error(Errno::ETIMEDOUT)
        expect(times_called).to eq(3)
      end
    end

    context 'with empty list of methods to retry' do
      let(:options) { [{ retry_if: @check, methods: [] }] }

      it 'calls retry_if for all methods' do
        @check = ->(_, _) { calls.size < 2 }
        expect { conn.get('/unstable') }.to raise_error(Errno::ETIMEDOUT)
        expect(times_called).to eq(2)
      end
    end
  end

  describe 'retry_after header support' do
    let(:callback) { -> { [504, headers, ''] } }
    let(:elapsed) { Time.now - @started }

    before do
      @started = Time.now
      conn.get('/unstable')
    end

    context 'when custom retry header is set' do
      let(:headers) { { 'x-retry-after' => '0.5' } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504, rate_limit_retry_header: 'x-retry-after' }] }

      it { expect(elapsed).to be > 0.5 }
    end

    context 'when custom reset header is set' do
      let(:headers) { { 'x-reset-after' => '0.5' } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504, rate_limit_reset_header: 'x-reset-after' }] }

      it { expect(elapsed).to be > 0.5 }
    end

    context 'when Retry-After bigger than RateLimit-Reset' do
      let(:headers) { { 'Retry-After' => '0.5', 'RateLimit-Reset' => '0.1' } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504 }] }

      it { expect(elapsed).to be > 0.5 }
    end

    context 'when RateLimit-Reset bigger than Retry-After' do
      let(:headers) { { 'Retry-After' => '0.1', 'RateLimit-Reset' => '0.5' } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504 }] }

      it { expect(elapsed).to be > 0.5 }
    end

    context 'when retry_after smaller than interval' do
      let(:headers) { { 'Retry-After' => '0.1' } }
      let(:options) { [{ max: 1, interval: 0.2, retry_statuses: 504 }] }

      it { expect(elapsed).to be > 0.2 }
    end

    context 'when RateLimit-Reset is a timestamp' do
      let(:headers) { { 'Retry-After' => '0.1', 'RateLimit-Reset' => (Time.now.utc + 2).strftime('%a, %d %b %Y %H:%M:%S GMT') } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504 }] }

      it { expect(elapsed).to be > 1 }
    end

    context 'when retry_after is a timestamp' do
      let(:headers) { { 'Retry-After' => (Time.now.utc + 2).strftime('%a, %d %b %Y %H:%M:%S GMT') } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504 }] }

      it { expect(elapsed).to be > 1 }
    end

    context 'when custom header_parser_block is set' do
      let(:headers) { { 'Retry-After' => '0.1', 'RateLimit-Reset' => (Time.now.utc + 2).to_i.to_s } }
      let(:options) { [{ max: 1, interval: 0.1, retry_statuses: 504, header_parser_block: ->(value) { Time.at(value.to_i).utc - Time.now.utc } }] }

      it { expect(elapsed).to be > 1 }
    end

    context 'when retry_after is bigger than max_interval' do
      let(:headers) { { 'Retry-After' => (Time.now.utc + 20).strftime('%a, %d %b %Y %H:%M:%S GMT') } }
      let(:options) { [{ max: 2, interval: 0.1, max_interval: 5, retry_statuses: 504 }] }

      it { expect(times_called).to eq(1) }

      context 'when retry_block is set' do
        let(:options) do
          [{
            retry_block: ->(**kwargs) { retry_block_calls << kwargs },
            max: 2,
            max_interval: 5,
            retry_statuses: 504
          }]
        end

        let(:retry_block_calls) { [] }
        let(:retry_block_times_called) { retry_block_calls.size }

        it 'retry_block is not called' do
          expect(retry_block_times_called).to eq(0)
        end
      end
    end
  end
end
