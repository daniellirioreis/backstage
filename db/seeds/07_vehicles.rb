puts "→ Criando veículos..."

[
  { model: "Argo",           color: "Branco",        plate: "RFW3G06" },
  { model: "Yamaha Factor 150", color: "Preta",      plate: "TZB8J29" },
  { model: "Palio",          color: "Preto",         plate: "HEM9D98" },
  { model: "Onix",           color: "Preto",         plate: "QUP4E03" },
  { model: "Sahara 300",     color: "Vermelha",      plate: "TEJ8E40" },
  { model: "Space Fox",      color: "Branco",        plate: "PWQ3I40" },
  { model: "Xre 300",        color: "Branca e Azul", plate: "QNW6H35" },
  { model: "Kwid",           color: "Branco",        plate: "RKF3E05" },
  { model: "Gol G5",         color: "Cinza",         plate: "HNK2J09" },
  { model: "Voyage",         color: "Branco",        plate: "FGB1J37" },
  { model: "Uno",            color: "Preto",         plate: "HJN5078" },
  { model: "Polo Track",     color: "Prata",         plate: "TYS6I99" },
  { model: "Onix",           color: "Prata",         plate: "PYV6362" },
  { model: "Corsa Hatch",    color: nil,             plate: "CMW7F70" },
  { model: "Fiat Idea",      color: "Dourado",       plate: "OLT2693" },
  { model: "Honda Fan 150",  color: "Cinza",         plate: "PWF6F82" },
  { model: "Kwid",           color: "Vermelho",      plate: "FZB0H01" },
  { model: "Uno",            color: "Cinza",         plate: "GYB7A08" },
].each do |v|
  Vehicle.find_or_create_by!(license_plate: v[:plate]) do |veh|
    veh.model = v[:model]
    veh.color = v[:color]
  end
end

puts "   Veículos: #{Vehicle.count}"
