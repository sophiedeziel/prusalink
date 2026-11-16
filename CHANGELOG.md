## [Unreleased]

- Write method signatures as inline RBS comments instead of `sig` blocks. Sorbet still checks them statically, but nothing is type-checked at runtime anymore, so a wrong argument type no longer raises a `TypeError` up front
- Ship `rbi/` in the gem: the exported signatures and the typed `auto_attr` readers, which Tapioca picks up in apps that use Sorbet
- Stop shipping the Tapioca DSL compiler (`lib/tapioca/`). `rbi/` already holds what it generates

## [0.1.1] - 2026-11-15

- Fix `Files::File#read_only` and `Files::Folder#read_only`, which were always `nil` on MK4, XL and MINI firmware. It sends `ro` instead of `read_only`
- Fix `Files.info` reporting `currently_printed: false` on MK4, XL and MINI firmware, which sends a `Currently-Printing` header instead of `Currently-Printed`
- Fix `Files.upload` raising a Sorbet `TypeError` on MK4, XL and MINI firmware, which answers with the uploaded file's JSON. It returns `true` again
- Raise `Prusalink::Exceptions::InvalidResponseError` instead of `JSON::ParserError` when the printer answers with invalid JSON, like XL firmware does for a job whose file was deleted
- Add `ServerVersion#server`, `#nozzle_diameter` and `#hostname`, which MK4, XL and MINI firmware send
- Add VCR cassettes recorded against a Prusa XL for every read-only endpoint

## [0.1.0] - 2026-11-15

- Initial release: client with HTTP Digest auth, version, info, status, job, storage, transfer and files resources
