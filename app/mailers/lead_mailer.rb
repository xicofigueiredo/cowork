class LeadMailer < ApplicationMailer
  def received(lead)
    @lead = lead

    mail(
      to: @lead.email,
      subject: "We received your message — Mezzanine"
    )
  end

  def introduce(email:, first_name: nil)
    @first_name = first_name.presence
    attachments.inline["flyer.jpeg"] = File.read(
      Rails.root.join("app/assets/images/flyer.jpeg")
    )

    mail(
      to: email,
      subject: "Mezzanine is opening in Matosinhos — space for your team"
    )
  end
end
