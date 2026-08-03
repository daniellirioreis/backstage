#!/bin/bash
# ──────────────────────────────────────────────────────────────
# tunnel.sh — acesso ao Backstage (localhost:3000) pelo celular
# ──────────────────────────────────────────────────────────────

PORT=3000

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           Backstage — Acesso pelo celular            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. IP local (mesma rede Wi-Fi) ────────────────────────────
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
if [ -n "$LOCAL_IP" ]; then
  echo "📱 Mesma rede Wi-Fi (sem internet, mais rápido):"
  echo "   http://$LOCAL_IP:$PORT"
  echo ""
fi

# ── 2. Túnel público via cloudflared ──────────────────────────
if ! command -v cloudflared &>/dev/null; then
  echo "⚙️  Instalando cloudflared..."
  brew install cloudflared 2>/dev/null || {
    echo "   brew não encontrado. Instale manualmente:"
    echo "   https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
    echo ""
    echo "   Ou use ngrok:"
    echo "   brew install ngrok && ngrok http $PORT"
    exit 1
  }
fi

echo "🌐 Iniciando túnel público (Cloudflare)..."
echo "   Aguarde o URL aparecer abaixo..."
echo "   (Ctrl+C para encerrar)"
echo ""
cloudflared tunnel --url http://localhost:$PORT
