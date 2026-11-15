# Claude Development Guide

This document contains important information for Claude when working on the PrusaLink gem.

## Architecture

The gem mirrors the architecture of the `octoprint` gem (github.com/sophiedeziel/octoprint):

- `Prusalink::Client` wraps Faraday. It parses JSON (deep-symbolized, underscored keys), maps HTTP statuses to `Prusalink::Exceptions::*`, and returns `nil` for a GET answered with 204 and `true` for any other empty body.
- `Prusalink::DigestAuth` is a Faraday middleware for HTTP Digest auth, which is what PrusaLink uses. It answers the 401 challenge, stores it to sign later requests up front, and retries once when the nonce goes stale. API keys (older firmware) are sent as `X-Api-Key`.
- `Prusalink::BaseResource` is the parent of every endpoint class (`resource_path`, `fetch_resource`, `post`, `put`, `patch`, `delete`, `head`).
- `AutoInitializable` (`auto_attr` + `auto_initialize!`) and `Deserializable` (`deserialize_config`) build typed value objects from API hashes. Every object has `auto_attr :extra, type: Hash`, which collects unknown fields.
- The client is stored per thread (`Prusalink.client`). `client.use { ... }` temporarily swaps it.
- `lib/tapioca/dsl/compilers/auto_initializable.rb` generates RBI signatures for `auto_attr` readers. Run `bin/tapioca dsl` after adding or changing attributes.

The API reference is the OpenAPI spec in prusa3d/Prusa-Link-Web (`spec/openapi.yaml`). It is AGPL, so don't copy it into this repo.

API names that clash with Ruby or read confusingly are renamed: `type` becomes `storage_type` / `file_type` / `transfer_type`.

## Tests

Most specs stub HTTP with WebMock. In those specs, `use_stubbed_printer` configures `http://printer.test` with an API key, so no Digest handshake is needed.

### Recording VCR cassettes against a real printer

1. Copy `.env.example` to `.env` and set `PRUSALINK_HOST`, `PRUSALINK_USERNAME` and `PRUSALINK_PASSWORD`.
2. Add `use_prusalink_server`, a `vcr: { cassette_name: "status/get" }` option, and the `:wip` tag to the example:
   ```ruby
   describe ".get", :wip, vcr: { cassette_name: "status/get" } do
     use_prusalink_server
     # ...
   end
   ```
3. Run the spec. With `:wip`, requests reach the printer and the cassette is recorded again from scratch (`record: :all`). If the spec fails, nothing is written. A `:wip` example without a `vcr:` option reaches the printer without recording anything.
4. Remove the `:wip` tag. Future runs replay the cassette and never touch the network (`record: :none`), so CI doesn't need a printer.

Tests that change printer state, like uploading or deleting files, should do their own setup and teardown. That way you can delete a cassette and record it again.

VCR replaces the host, password and username with `<HOST>`, `<PASSWORD>` and `<USERNAME>`, the printer's serial number with `<SERIAL>`, and the hash in Digest `Authorization` headers with `<DIGEST>` (with the nonce, it would be enough to brute-force the password). A spec in `spec/integration/printer_spec.rb` fails if a cassette contains a serial number or a Digest hash. Cassettes record the 401 challenge and the signed retry.

## Quality gates

```bash
bin/check            # rspec + rubocop + sorbet
bin/tapioca dsl      # regenerate RBIs after changing auto_attr declarations
```

- Coverage must stay at 100% (SimpleCov `minimum_coverage 100`). Always run the full suite to measure it.
