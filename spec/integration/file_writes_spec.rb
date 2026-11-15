# typed: true
# frozen_string_literal: true

# Uploads and deletions on a real printer, replayed from VCR cassettes (see "Recording VCR cassettes" in CLAUDE.md).
#
# After each upload, MK4, XL and MINI firmware open a print preview ("print this file?") on the printer's screen,
# which shows up as a job waiting for confirmation. The examples close it by stopping that job, then wait until the
# printer is idle again.
#
# Every example only touches the test file, which it uploads itself, so recording again is safe and repeatable:
# - before: checks that the printer is idle, without a job, and that the test file doesn't exist. Otherwise it aborts
#   without touching anything.
# - after: even when the example failed, stops the job if it's the test file's (and never any other), deletes the
#   test file if it's still there, then checks that the printer is idle and the file gone.
# Both talk to the printer outside the cassette, and only while recording. Replays never reach the network.
#
# The uploaded file is spec/files/inert.gcode. Even if it were printed, it never moves, heats or extrudes.
#
# TODO: not recorded yet. A plain preview doesn't show up as a job, so `close_preview` can't close it and the file
# stays locked. See TODO.md for the plan.
RSpec.describe "PrusaLink file writes", skip: "Not recorded yet: the firmware's print preview needs someone at " \
                                              "the printer, see TODO.md", type: :integration do
  use_prusalink_server

  def test_file = "prusalink-gem-test.gcode"
  def storage = "usb"
  def inert_gcode = File.expand_path("../files/inert.gcode", __dir__)

  def test_file_present?
    Prusalink::Files.exists?(storage: storage, path: test_file)
  end

  def our_job?(job)
    job&.file&.display_name == test_file
  end

  def printer_state
    Prusalink::Status.get&.printer&.state
  end

  def ensure_idle!
    state = printer_state
    raise "Aborting: the printer is #{state.inspect}, not idle" unless %w[IDLE READY FINISHED STOPPED].include?(state)
    raise "Aborting: a job is running" if Prusalink::Job.get
  end

  def monotonic_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Polls until the block returns something truthy. Waits between attempts, except when replaying a cassette.
  def wait_for(description, timeout: 20)
    deadline = monotonic_now + timeout
    loop do
      result = yield
      return result if result
      raise "Timed out after #{timeout}s waiting for #{description}" if monotonic_now > deadline

      sleep 0.5 unless VCR.current_cassette && !recording_cassette?
    end
  end

  def wait_until_idle
    wait_for("the printer to be idle") { printer_state == "IDLE" }
  end

  # Closes the print preview the firmware opens after an upload, by stopping its job
  def close_preview
    job = wait_for("the print preview of #{test_file}") { Prusalink::Job.get.then { |j| j if our_job?(j) } }
    job.stop
    wait_until_idle
    job
  end

  before do |example|
    next unless recording_cassette?

    unrecorded do
      ensure_idle!
      raise "Aborting: #{test_file} is already on the printer, see CLAUDE.md to remove it" if test_file_present?
    end

    # The file is absent, so anything at this path from now on was uploaded by this example
    example.metadata[:clean_start] = true
  end

  after do |example|
    next unless recording_cassette? && example.metadata[:clean_start]

    unrecorded do
      job = Prusalink::Job.get
      if job
        raise "Cleanup stopped: job #{job.id} isn't #{test_file}'s, leaving it alone" unless our_job?(job)

        job.stop
        wait_until_idle
      end

      Prusalink::Files.delete(storage: storage, path: test_file) if test_file_present?
      raise "Cleanup failed: #{test_file} is still on the printer" if test_file_present?

      ensure_idle!
    end
  end

  # Once every example ran, check one last time that the printer is left as it was found.
  # It only checks the printer, so no state can leak between examples.
  after(:context) do # rubocop:disable RSpec/BeforeAfterAll
    next unless self.class.metadata[:wip]

    WebMock.allow_net_connect!
    unrecorded do
      raise "Cleanup failed: #{test_file} is still on the printer" if test_file_present?

      ensure_idle!
    end
  ensure
    WebMock.disable_net_connect!
  end

  describe "uploading, reading and deleting a file", vcr: { cassette_name: "files/upload_and_delete" } do
    it "goes through the whole lifecycle" do
      expect(Prusalink::Files.exists?(storage: storage, path: test_file)).to be(false)

      expect(Prusalink::Files.upload(inert_gcode, storage: storage, path: test_file)).to be(true)
      preview = close_preview
      expect(preview).to have_attributes(id: a_kind_of(Integer))
      expect(preview.file).to have_attributes(display_name: test_file, path: "/usb")

      expect(Prusalink::Files.exists?(storage: storage, path: test_file)).to be(true)
      expect(Prusalink::Files.get(storage: storage, path: test_file)).to have_attributes(
        display_name: test_file,
        file_type: "PRINT_FILE",
        read_only: false,
        size: File.size(inert_gcode)
      )
      expect(Prusalink::Files.info(storage: storage, path: test_file))
        .to eq(read_only: false, currently_printed: false)

      expect(Prusalink::Files.delete(storage: storage, path: test_file)).to be(true)
      expect(Prusalink::Files.exists?(storage: storage, path: test_file)).to be(false)
    end
  end

  describe "uploading over an existing file", vcr: { cassette_name: "files/upload_conflict" } do
    it "raises ConflictError unless overwrite is true" do
      expect(Prusalink::Files.upload(inert_gcode, storage: storage, path: test_file)).to be(true)
      close_preview

      expect { Prusalink::Files.upload(inert_gcode, storage: storage, path: test_file) }
        .to raise_error(Prusalink::Exceptions::ConflictError)

      expect(Prusalink::Files.upload(inert_gcode, storage: storage, path: test_file, overwrite: true)).to be(true)
      close_preview

      expect(Prusalink::Files.delete(storage: storage, path: test_file)).to be(true)
    end
  end

  describe "uploading from an IO", vcr: { cassette_name: "files/upload_io" } do
    # The upload is the first request, so the client fetches the Digest challenge with a HEAD before streaming
    it "streams it after fetching the Digest challenge" do
      io = StringIO.new(File.read(inert_gcode))

      expect(Prusalink::Files.upload(io, storage: storage, path: test_file)).to be(true)
      close_preview
      expect(Prusalink::Files.exists?(storage: storage, path: test_file)).to be(true)

      expect(Prusalink::Files.delete(storage: storage, path: test_file)).to be(true)
    end
  end

  describe "deleting a missing file", vcr: { cassette_name: "files/delete_missing" } do
    it "raises NotFoundError" do
      expect { Prusalink::Files.delete(storage: storage, path: "missing.bgcode") }
        .to raise_error(Prusalink::Exceptions::NotFoundError)
    end
  end
end
