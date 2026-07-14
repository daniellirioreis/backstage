#!/bin/bash
# capture_screenshots.sh — versão corrigida (screencapture de tela cheia)
# Uso: cd ~/Documents/GitHub/backstage && bash capture_screenshots.sh

PORTFOLIO="$(pwd)/public/portfolio"
mkdir -p "$PORTFOLIO"

capture() {
  local url="$1"
  local file="$2"
  echo "📸 $file"

  osascript -e "tell application \"Google Chrome\"
    activate
    set URL of active tab of window 1 to \"$url\"
  end tell"

  sleep 3
  screencapture -x "$PORTFOLIO/$file"
}

echo "🚀 Capturando screenshots para o portfólio..."
echo "   Destino: $PORTFOLIO"
echo ""

capture "http://localhost:3000/"                          "screen-home.png"
capture "http://localhost:3000/events"                    "screen-events.png"
capture "http://localhost:3000/events/13"                 "screen-evento-overview.png"
capture "http://localhost:3000/events/13#financeiro"      "screen-financeiro.png"
capture "http://localhost:3000/events/13#equipes"         "screen-equipes.png"
capture "http://localhost:3000/events/13#setores"         "screen-setores.png"
capture "http://localhost:3000/shifts/timeline"           "screen-timeline.png"
capture "http://localhost:3000/attendances"               "screen-presencas.png"
capture "http://localhost:3000/reports/closing"           "screen-fechamento.png"
capture "http://localhost:3000/reports/sector_summary"    "screen-setor-resumo.png"
capture "http://localhost:3000/events/14/edit"            "screen-evento-edit.png"
capture "http://localhost:3000/events/14/setup/sectors"   "screen-setup-setores.png"
capture "http://localhost:3000/events/14/setup/teams"     "screen-setup-equipes.png"
capture "http://localhost:3000/events/14/setup/schedules" "screen-setup-escalas.png"

COUNT=$(ls "$PORTFOLIO"/screen-*.png 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "✅ $COUNT screenshots salvos em public/portfolio/"
