require "set"

class IntroduceCampaign
  DEFAULT_FILE = Rails.root.join("db/leads.csv")
  DEFAULT_SENT_LOG = Rails.root.join("tmp/introduce_campaign_sent.log")
  DEFAULT_DELAY = 45

  Result = Struct.new(:sent, :skipped, :failed, :dry_run, keyword_init: true)

  def self.call(**)
    new(**).call
  end

  def initialize(
    file: DEFAULT_FILE,
    dry_run: true,
    delay: DEFAULT_DELAY,
    sent_log: DEFAULT_SENT_LOG,
    output: $stdout
  )
    @file = Pathname(file)
    @dry_run = dry_run
    @delay = delay.to_f
    @sent_log = Pathname(sent_log)
    @output = output
  end

  def call
    raise ArgumentError, "File not found: #{@file}" unless @file.exist?

    emails = parse_emails
    already_sent = load_sent_emails
    sent = []
    skipped = []
    failed = []

    mode = @dry_run ? "DRY RUN" : "LIVE"
    log "#{mode}: #{emails.size} address(es) in #{@file}"

    emails.each_with_index do |email, index|
      if already_sent.include?(email)
        skipped << email
        log "skip (already sent): #{email}"
        next
      end

      if @dry_run
        sent << email
        log "would send: #{email}"
        next
      end

      begin
        LeadMailer.introduce(email: email).deliver_now
        record_sent(email)
        already_sent << email
        sent << email
        log "sent: #{email}"
      rescue StandardError => e
        failed << email
        log "failed: #{email} (#{e.class}: #{e.message})"
        next
      end

      remaining = emails[(index + 1)..]&.reject { |e| already_sent.include?(e) } || []
      sleep @delay if @delay.positive? && remaining.any?
    end

    log "Done. sent=#{sent.size} skipped=#{skipped.size} failed=#{failed.size}"
    Result.new(sent: sent, skipped: skipped, failed: failed, dry_run: @dry_run)
  end

  private

  def parse_emails
    seen = {}

    @file.each_line.filter_map do |line|
      value = line.strip.downcase
      next if value.blank? || value.start_with?("#")
      next unless value.match?(URI::MailTo::EMAIL_REGEXP)
      next if seen[value]

      seen[value] = true
      value
    end
  end

  def load_sent_emails
    return Set.new unless @sent_log.exist?

    Set.new(
      @sent_log.each_line.filter_map do |line|
        email = line.split("\t", 2).first&.strip&.downcase
        email if email.present?
      end
    )
  end

  def record_sent(email)
    @sent_log.dirname.mkpath
    File.open(@sent_log, "a") do |f|
      f.puts "#{email}\t#{Time.current.iso8601}"
    end
  end

  def log(message)
    @output.puts(message)
  end
end
