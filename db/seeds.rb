Dir[File.join(__dir__, "seeds", "*.rb")].sort.each do |file|
  load file
end

puts "\nSeed concluído!"
puts "  Roles:        #{Role.count}"
puts "  Eventos:      #{Event.count}"
puts "  Equipes:      #{Team.count}"
puts "  Setores:      #{Sector.count}"
puts "  Colaboradores: #{User.count - 1} (+ 1 admin)"
puts "  Veículos:     #{Vehicle.count}"
