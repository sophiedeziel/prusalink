# PrusaLink Ruby Gem

A type-safe Ruby wrapper for **PrusaLink**, the local REST API built into Prusa 3D printers, with full Sorbet integration.

Works with printers running PrusaLink: MK4/MK4S, MK3.9, MK3.5, XL, MINI/MINI+ and Core One with recent firmware, and MK3/MK3S/MK2.5 with a Raspberry Pi running PrusaLink.

Same architecture as the [`octoprint`](https://github.com/sophiedeziel/octoprint) gem.

## ✨ Key Features

- **🔐 Digest auth built in**: PrusaLink uses HTTP Digest authentication, and the gem handles the challenge, nonce rotation and retries for you. API keys (older firmware) work too.
- **🛡️ Type Safety**: Sorbet signatures on every resource, and RBI files generated for every attribute
- **🔥 Smart Error Handling**: HTTP statuses mapped to specific exception types
- **🎯 Multi-Printer Support**: thread-local clients, and `client.use { }` to talk to several printers
- **⚡ Modern Ruby**: Ruby 3.3+, Zeitwerk autoloading

## Installation

```ruby
gem "prusalink", github: "sophiedeziel/prusalink"
```

## Usage

### Configuration

Turn on PrusaLink on the printer (Settings > Network > PrusaLink). The screen shows the username (`maker` by default) and the password.

```ruby
require "prusalink"

Prusalink.configure(host: "http://192.168.1.42", password: "from-the-printer-screen")

# Older firmware with an API key
Prusalink.configure(host: "http://192.168.1.43", api_key: "abcdef")

# Custom username and timeouts (defaults: open_timeout 3s, timeout 10s)
Prusalink.configure(host: "http://prusa-xl.local", username: "maker", password: "...", timeout: 30)
```

### Several printers

```ruby
mk4  = Prusalink::Client.new(host: "http://192.168.1.42", password: "...")
mini = Prusalink::Client.new(host: "http://192.168.1.43", api_key: "...")

mk4.use  { Prusalink::Status.get }
mini.use { Prusalink::Status.get }
```

### Printer status and telemetry

```ruby
status = Prusalink::Status.get
status.printer.state        # => "PRINTING"
status.printer.printing?    # => true
status.printer.temp_nozzle  # => 214.9
status.printer.temp_bed     # => 59.5
status.job&.progress        # => 42.0
status.job&.time_remaining  # => 520 (seconds)

info = Prusalink::Info.get
info.name                   # => "MuadDib"
info.serial                 # => "CZPX4720X004XC34242"

Prusalink::ServerVersion.get.text # => "PrusaLink"
```

### Jobs

```ruby
job = Prusalink::Job.get    # => nil when nothing is printing
job.state                   # => "PRINTING"
job.progress                # => 42.0
job.file.display_name       # => "benchy_0.4n_0.2mm_PLA_MK4_1h2m.bgcode"

job.pause
job.resume
job.stop

Prusalink::Job.pause(job.id) # or by id
```

### Files and storage

```ruby
Prusalink::Storage.list.map(&:path)   # => ["/usb"]

# Upload, and optionally start printing
Prusalink::Files.upload("benchy.bgcode", storage: "usb", path: "benchy.bgcode", print_after_upload: true)

# Browse
folder = Prusalink::Files.get(storage: "usb")
folder.children.map(&:display_name)

# Print, check and delete existing files
Prusalink::Files.print(storage: "usb", path: "benchy.bgcode")
Prusalink::Files.exists?(storage: "usb", path: "benchy.bgcode") # => true
Prusalink::Files.delete(storage: "usb", path: "benchy.bgcode")
```

For large uploads, give the client a longer `timeout:`.

### Transfers

```ruby
transfer = Prusalink::Transfer.get    # => nil when nothing is uploading
transfer&.progress                    # => 65.82
```

### Error handling

```ruby
begin
  Prusalink::Job.pause(42)
rescue Prusalink::Exceptions::ConflictError => e
  # The printer isn't printing
rescue Prusalink::Exceptions::AuthenticationError
  # Wrong password or API key
rescue Prusalink::Exceptions::TimeoutError, Prusalink::Exceptions::ConnectionError
  # Printer offline or unreachable
end
```

| Status | Exception |
|---|---|
| 400 | `BadRequestError` |
| 401, 403 | `AuthenticationError` |
| 404 | `NotFoundError` |
| 409 | `ConflictError` |
| 415 | `UnsupportedMediaTypeError` |
| 500 | `InternalServerError` |
| 501 | `NotImplementedError` |
| 503 | `ServiceUnavailableError` |
| other | `UnknownError` |

All of them inherit from `Prusalink::Exceptions::Error`.

## API coverage

| Endpoint | Resource |
|---|---|
| `GET /api/version` | `ServerVersion.get` |
| `GET /api/v1/info` | `Info.get` |
| `GET /api/v1/status` | `Status.get` |
| `GET/DELETE /api/v1/job`, `PUT .../pause`, `.../resume`, `.../continue` | `Job` |
| `GET /api/v1/storage` | `Storage.list` |
| `GET/DELETE /api/v1/transfer` | `Transfer` |
| `GET/PUT/POST/HEAD/DELETE /api/v1/files/{storage}/{path}` | `Files` |
| `/api/v1/cameras/*` | not yet |
| `/api/v1/update/*` | not yet |

## Development

```bash
bin/setup        # install dependencies
bin/check        # rspec + rubocop + sorbet
bin/tapioca dsl  # regenerate RBIs after changing auto_attr declarations
bin/console      # interactive prompt
```

To record VCR cassettes against a real printer, see [CLAUDE.md](CLAUDE.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
