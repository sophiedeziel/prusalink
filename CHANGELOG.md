## [Unreleased]

- Fix `Files::File#read_only` and `Files::Folder#read_only`, which were always `nil` on MK4, XL and MINI firmware. It sends `ro` instead of `read_only`
- Fix `Files.info` reporting `currently_printed: false` on MK4, XL and MINI firmware, which sends a `Currently-Printing` header instead of `Currently-Printed`
- Add `ServerVersion#server`, `#nozzle_diameter` and `#hostname`, which MK4, XL and MINI firmware send

## [0.1.0] - 2026-11-15

- Initial release: client with HTTP Digest auth, version, info, status, job, storage, transfer and files resources
