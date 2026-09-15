class ApplicationMailer < ActionMailer::Base
  default from: "Mezzanine <hello@mezzaninecowork.com>"
  layout "mailer"

  private

  def admin_emails
    ENV.fetch("ADMIN_EMAILS", "").split(",").map { |e| e.strip }.reject(&:blank?)
  end
end
