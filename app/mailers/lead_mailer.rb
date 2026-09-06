class LeadMailer < ApplicationMailer
  def received(lead)
    @lead = lead

    mail(
      to: @lead.email,
      subject: "We received your message — Mezzanine"
    )
  end
end
