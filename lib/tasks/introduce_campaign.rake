namespace :introduce do
  desc "Send introduce emails from a one-email-per-line file (dry-run unless SEND=1)"
  task send: :environment do
    dry_run = ENV["SEND"] != "1"
    file = ENV.fetch("FILE", IntroduceCampaign::DEFAULT_FILE)
    delay = ENV.fetch("DELAY", IntroduceCampaign::DEFAULT_DELAY)

    if dry_run
      puts "Dry run only. Set SEND=1 to deliver for real."
    else
      puts "LIVE send starting — delay #{delay}s between messages."
    end

    IntroduceCampaign.call(
      file: file,
      dry_run: dry_run,
      delay: delay
    )
  end
end
