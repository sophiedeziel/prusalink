# Claude Development Guide

This document contains important information for Claude when working on the PrusaLink gem.

## Architecture

The gem mirrors the architecture of the `octoprint` gem (github.com/sophiedeziel/octoprint):

- `Prusalink::Client` wraps Faraday. It parses JSON (deep-symbolized, underscored keys), maps HTTP statuses to `Prusalink::Exceptions::*`, and returns `nil` for a GET answered with 204 and `true` for any other empty body.
- `Prusalink::DigestAuth` is a Faraday middleware for HTTP Digest auth, which is what PrusaLink uses. It answers the 401 challenge, stores it to sign later requests up front, and retries once when the nonce goes stale. API keys (older firmware) are sent as `X-Api-Key`.
- `Prusalink::BaseResource` is the parent of every endpoint class (`resource_path`, `fetch_resource`, `post`, `put`, `patch`, `delete`, `head`).
- `AutoInitializable` (`auto_attr` + `auto_initialize!`) and `Deserializable` (`deserialize_config`) build typed value objects from API hashes. Every object has `auto_attr :extra, type: Hash`, which collects unknown fields.
- The client is stored per thread (`Prusalink.client`). `client.use { ... }` temporarily swaps it.
- `lib/tapioca/dsl/compilers/auto_initializable.rb` generates RBI signatures for `auto_attr` readers. Run `bin/tapioca dsl` after adding or changing attributes. It isn't shipped in the gem.

The API reference is the OpenAPI spec in prusa3d/Prusa-Link-Web (`spec/openapi.yaml`). It is AGPL, so don't copy it into this repo.

API names that clash with Ruby or read confusingly are renamed: `type` becomes `storage_type` / `file_type` / `transfer_type`.

## Type signatures (RBS comments)

Method signatures are inline RBS comments that Sorbet checks statically. They don't run at runtime, which is on purpose: the gem does no runtime type checking in production.

- Write `#: (String, ?force: bool) -> bool` directly above the `def`. Use `#|` to continue a long signature over several lines. Don't use `sig { ... }` blocks or `extend T::Sig`.
- Keep the YARD doc comment directly above the `#:` line with no blank line between them. `.yard/rbs_comments.rb` strips the signature out of the generated docs. `bundle exec yard stats --list-undoc` should stay at 100%.
- After changing a public signature or an `auto_attr`, run `bin/tapioca dsl` and then `bundle exec rake rbi:export` to regenerate `rbi/`. It holds the RBS signatures exported by Spoom (`rbi/prusalink.rbi`) and a copy of the Tapioca DSL RBIs for `auto_attr` readers (`rbi/prusalink/**`), with superclasses added so the files merge without conflicts. The gem ships this folder so Tapioca can type the gem in apps that use Sorbet, and CI (`bundle exec rake rbi:check`) fails when it's out of date.
- Tapioca turns the `#:` comments into runtime signatures when it loads the gem, and sorbet-runtime checks overrides. A method that overrides its parent with a different signature, like `Files.delete`, needs `# @override(allow_incompatible: true)` above its `#:` line, or apps get it untyped.
- `bundle exec spoom srb sigs translate` converts `sig` blocks to RBS comments if you paste in old-style code.

## Tests

Most specs stub HTTP with WebMock. In those specs, `use_stubbed_printer` configures `http://printer.test` with an API key, so no Digest handshake is needed.

### Recording VCR cassettes against a real printer

1. Copy `.env.example` to `.env` and set `PRUSALINK_HOST`, `PRUSALINK_USERNAME` and `PRUSALINK_PASSWORD`.
2. In the class's spec, next to its WebMock examples, add a `context "with a real printer"` with `use_prusalink_server`, a `vcr:` option named after the class and method, and the `:wip` tag:
   ```ruby
   context "with a real printer", :wip, vcr: { cassette_name: "status/get" } do
     use_prusalink_server
     # ...
   end
   ```
3. Run the spec. With `:wip`, requests reach the printer and the cassette is recorded again from scratch (`record: :all`). If the spec fails, nothing is written. A `:wip` example without a `vcr:` option reaches the printer without recording anything.
4. Remove the `:wip` tag. Future runs replay the cassette and never touch the network (`record: :none`), so CI doesn't need a printer.

Tests that change printer state, like uploading or deleting files, should do their own setup and teardown. That way you can delete a cassette and record it again. In those hooks, `unrecorded { ... }` talks to the printer with its own client, without saving anything to the cassette, and `recording_cassette?` tells whether the example is recording.

Write operations aren't recorded yet. See `TODO.md`: on MK4, XL and MINI firmware, every upload opens a print preview on the printer's screen that locks the file until someone closes it.

If a recording run left `prusalink-gem-test.gcode` on the printer, delete it with the command below. If it answers `409 File is busy`, close the print preview on the printer's screen first.

```bash
bundle exec ruby -Ilib -rdotenv/load -rprusalink -e 'Prusalink.configure(host: ENV["PRUSALINK_HOST"], username: ENV["PRUSALINK_USERNAME"], password: ENV["PRUSALINK_PASSWORD"]); Prusalink::Files.delete(storage: "usb", path: "prusalink-gem-test.gcode")'
```

VCR replaces the host, password and username with `<HOST>`, `<PASSWORD>` and `<USERNAME>`, the printer's serial number with `<SERIAL>`, and the hash in Digest `Authorization` headers with `<DIGEST>` (with the nonce, it would be enough to brute-force the password). `spec/integration/cassettes_spec.rb` fails if a cassette contains a serial number or a Digest hash. Cassettes record the 401 challenge and the signed retry. The cassettes were recorded on a Prusa XL while it was idle. Its USB drive had an empty `Single-Tool` folder and the SmartTemperatureTower calibration print at its root.

## Quality gates

```bash
bin/check                     # rspec + rubocop + sorbet + rbi:check
bin/tapioca dsl               # regenerate RBIs after changing auto_attr declarations
bundle exec rake rbi:export   # regenerate rbi/ after changing a signature or an auto_attr
```

- Coverage must stay at 100% (SimpleCov `minimum_coverage 100`). Always run the full suite to measure it.
