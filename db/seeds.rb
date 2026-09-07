# Seeds for cowork space seats (desks 001–025)
seats = (1..18).map { |n| { code: format("%03d", n), floor: "main" } } +
        (19..25).map { |n| { code: format("%03d", n), floor: "mezzanine" } }

seats.each do |attrs|
  seat = Seat.find_or_initialize_by(code: attrs[:code])
  seat.floor = attrs[:floor]
  seat.kind = "desk"
  seat.save!
end

meeting = Seat.find_or_initialize_by(code: "meeting")
meeting.floor = "meeting"
meeting.kind = "meeting_room"
meeting.save!

MonthlyMeetingCreditsBackfill.call if defined?(MonthlyMeetingCreditsBackfill)

puts "Seeded #{Seat.count} seats (#{Seat.desks.count} desks + meeting room)"
