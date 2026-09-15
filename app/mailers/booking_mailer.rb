class BookingMailer < ApplicationMailer
  CHANGE_ATTRS = %w[date seat_id starts_on ends_on starts_at ends_at].freeze

  def self.deliver_created(booking)
    created(booking).deliver_now
  rescue StandardError => e
    Rails.logger.error("Booking created admin email failed for booking #{booking.id}: #{e.class}: #{e.message}")
  end

  def self.deliver_updated(booking, changes:)
    relevant = changes.slice(*CHANGE_ATTRS)
    return if relevant.empty?

    updated(booking, changes: relevant).deliver_now
  rescue StandardError => e
    Rails.logger.error("Booking updated admin email failed for booking #{booking.id}: #{e.class}: #{e.message}")
  end

  def created(booking)
    @booking = booking
    @user = booking.user
    @seat = booking.seat
    @member_name = member_name_for(@user)

    mail(
      to: admin_recipients,
      subject: "New booking — #{@member_name} — #{booking.period_label}"
    )
  end

  def updated(booking, changes:)
    @booking = booking
    @user = booking.user
    @seat = booking.seat
    @member_name = member_name_for(@user)
    @changes = format_changes(changes)

    mail(
      to: admin_recipients,
      subject: "Booking updated — #{@member_name} — #{booking.period_label}"
    )
  end

  private

  def admin_recipients
    admin_emails.presence || [ "hello@mezzaninecowork.com" ]
  end

  def member_name_for(user)
    "#{user.first_name} #{user.last_name}".strip
  end

  def format_changes(changes)
    changes.filter_map do |attr, (before, after)|
      next if before == after

      {
        label: attr_label(attr),
        before: format_value(attr, before),
        after: format_value(attr, after)
      }
    end
  end

  def attr_label(attr)
    {
      "date" => "Date",
      "seat_id" => "Seat",
      "starts_on" => "Starts on",
      "ends_on" => "Ends on",
      "starts_at" => "Starts at",
      "ends_at" => "Ends at"
    }.fetch(attr, attr.humanize)
  end

  def format_value(attr, value)
    return "—" if value.nil?

    case attr
    when "seat_id"
      Seat.find_by(id: value)&.label || value.to_s
    when "date", "starts_on", "ends_on"
      value.to_date.strftime("%-d %B %Y")
    when "starts_at", "ends_at"
      value.in_time_zone.strftime("%-d %B %Y, %H:%M")
    else
      value.to_s
    end
  end
end
