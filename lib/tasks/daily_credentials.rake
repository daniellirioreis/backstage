namespace :daily_credentials do
  desc "Gera DailyCredentials para TeamMemberships que ainda não as possuem"
  task backfill: :environment do
    total = 0
    TeamMembership.find_each do |tm|
      event = tm.team&.sector&.event
      next unless event

      event.event_days.each do |ed|
        dc = tm.daily_credentials.find_or_initialize_by(date: ed.date)
        if dc.new_record?
          dc.save!
          total += 1
        end
      end
    end
    puts "✓ #{total} DailyCredentials criadas."
  end
end
