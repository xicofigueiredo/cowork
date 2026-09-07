require "test_helper"
require "stringio"

class IntroduceCampaignTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  setup do
    @dir = Rails.root.join("tmp/introduce_campaign_test")
    FileUtils.rm_rf(@dir)
    FileUtils.mkdir_p(@dir)
    @csv = @dir.join("leads.csv")
    @sent_log = @dir.join("sent.log")
    @output = StringIO.new
  end

  teardown do
    FileUtils.rm_rf(@dir)
  end

  test "dry run does not deliver mail" do
    write_csv <<~CSV
      ada@example.com
      grace@example.com
      not-an-email
      # comment
      ada@example.com
    CSV

    assert_emails 0 do
      result = IntroduceCampaign.call(
        file: @csv,
        dry_run: true,
        delay: 0,
        sent_log: @sent_log,
        output: @output
      )

      assert result.dry_run
      assert_equal [ "ada@example.com", "grace@example.com" ], result.sent
      assert_empty result.skipped
      assert_empty result.failed
    end

    assert_not File.exist?(@sent_log)
  end

  test "live mode delivers once per unique email and skips already sent" do
    write_csv <<~CSV
      ada@example.com
      grace@example.com
      invalid
    CSV

    File.write(@sent_log, "ada@example.com\t2026-01-01T00:00:00Z\n")

    assert_emails 1 do
      result = IntroduceCampaign.call(
        file: @csv,
        dry_run: false,
        delay: 0,
        sent_log: @sent_log,
        output: @output
      )

      assert_not result.dry_run
      assert_equal [ "grace@example.com" ], result.sent
      assert_equal [ "ada@example.com" ], result.skipped
      assert_empty result.failed
    end

    log = File.read(@sent_log)
    assert_includes log, "grace@example.com"
  end

  test "raises when file is missing" do
    assert_raises(ArgumentError) do
      IntroduceCampaign.call(
        file: @dir.join("missing.csv"),
        dry_run: true,
        delay: 0,
        sent_log: @sent_log,
        output: @output
      )
    end
  end

  private

  def write_csv(contents)
    File.write(@csv, contents)
  end
end
