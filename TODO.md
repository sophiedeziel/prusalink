# TODO

## Record VCR cassettes for write operations (needs someone at the printer)

Every read-only endpoint has a cassette recorded against a Prusa XL, in a `with a real printer` context of its class's spec.
The write operations don't yet: `describe "writing to a real printer"` in `spec/prusalink/files_spec.rb` is skipped until
they're recorded.

### Why it needs someone at the printer

On MK4, XL and MINI firmware, every G-code upload to an idle printer opens a print preview ("print this file?") on
the printer's screen, even with `Print-After-Upload: ?0`:

- `wui_start_print` in `lib/WUI/wui_api.cpp` (Prusa-Firmware-Buddy) calls `print_start` on every upload. The
  preview opens whenever `remote_print_ready` (`src/state/printer_state.cpp`) sees an Idle, Ready, Stopped or
  Finished printer.
- A plain preview doesn't show up in the API: the status is `IDLE` and `GET /api/v1/job` answers 204. It only appears
  as a job (which `Job.stop` can close) when the preview asks a question, like a filament or compatibility warning.
- While the preview is open, the file is locked: deleting it answers `409 File is busy`. Someone has to close the
  preview on the screen.
- Uploading something other than G-code doesn't avoid it: the firmware answers `415 Not a GCODE`.
- No preview opens while the printer is busy, e.g. printing.

### Plan

Pick one:

- **(a) Close the previews by hand.** Record with someone at the printer who closes each preview (about 4). Simplest,
  never starts a print, but every new recording needs someone there.
- **(b) Use an inert print as a shield** (recommended). Upload `spec/files/inert.gcode` with
  `print_after_upload: true`, which passes `PreviewSkipIfAble::all`, so the print should start without a preview.
  While it runs, no preview opens, so the upload, conflict and delete tests can run and clean up from the API. Then
  stop the inert job and delete its file. Fully repeatable from the API afterwards.
  Before trying it, check in the firmware code what "if able" means (which warnings still show a screen) and what an
  XL does when a print starts without homing. The first recording needs someone at the printer, with the bed clear,
  ready to press Stop.

Whatever the choice, keep these safety rules, already enforced in `files_spec.rb`:

- Only touch `prusalink-gem-test.gcode`, uploaded by the example itself. Never delete or overwrite anything else.
- Before each example: the printer is idle, has no job, and the test file doesn't exist. Otherwise abort.
- After each example, even on failure: stop the job only if it's the test file's, delete the test file, then check
  that the printer is idle and the file gone.
- Any print we start is stopped by the test.

`files_spec.rb` currently closes the preview by stopping its job (`close_preview`), which only works when the
preview shows up as a job. Rework it for (a) or (b) before recording.

### Write operations still without a cassette

- [ ] `Files.upload` from a path, from an IO (streamed after a HEAD that fetches the Digest challenge), and with
      `overwrite: true` / a 409 without it
- [ ] `Files.upload(print_after_upload: true)`
- [ ] `Files.delete`, a 409 while the file is printed, and a 404 for a missing file
- [ ] `Files.print`
- [ ] `Job.get` with a job, `Status.get` while printing, `Files.info` with `currently_printed: true` (proves the
      `Currently-Printing` fix against real firmware)
- [ ] `Job.pause`, `Job.resume`, `Job.stop`. On pause, the firmware normally parks the head: check what an XL that
      isn't homed does before recording it
- [ ] `Transfer.get` during a transfer and `Transfer.stop` (needs an upload slow enough to catch, e.g. a large file
      from a thread, without leaving a partial file behind)
- [ ] `Job.continue` (only valid while the printer waits after a timelapse capture, probably can't be recorded safely)
