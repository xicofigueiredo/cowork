# Seeds for cowork space seats (desks 001–025)
seats = (1..18).map { |n| { code: format("%03d", n), floor: "main" } } +
        (19..25).map { |n| { code: format("%03d", n), floor: "mezzanine" } }

seats.each do |attrs|
  Seat.find_or_create_by!(code: attrs[:code]) do |seat|
    seat.floor = attrs[:floor]
    seat.kind = "desk"
  end
end

Seat.find_or_create_by!(code: "meeting") do |seat|
  seat.floor = "meeting"
  seat.kind = "meeting_room"
end

MonthlyMeetingCreditsBackfill.call

puts "Seeded #{Seat.count} seats (#{Seat.desks.count} desks + meeting room)"
