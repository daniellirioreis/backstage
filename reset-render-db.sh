#!/bin/bash
# reset-render-db.sh
# Uso: bash reset-render-db.sh
# Reseta o banco de produção no Render via deploy temporário.

set -e

echo "⚠️  ATENÇÃO: isso vai apagar todos os dados de produção no Render!"
read -p "   Tem certeza? (s/N) " confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

echo ""
echo "🔁 Passo 1/2 — Ativando build de reset..."
cp bin/render-build.sh bin/render-build.sh.bak
cp bin/render-build-reset.sh bin/render-build.sh

git add bin/render-build.sh
git commit -m "chore: reset production DB [render]"
git push origin main

echo ""
echo "🚀 Deploy de reset iniciado no Render!"
echo "   Acesse https://dashboard.render.com para acompanhar."
echo "   Aguarde o deploy finalizar antes de continuar."
echo ""
read -p "✅ Deploy finalizado? Pressione ENTER para restaurar o build normal..."

echo ""
echo "🔁 Passo 2/2 — Restaurando build normal..."
cp bin/render-build.sh.bak bin/render-build.sh
rm bin/render-build.sh.bak

git add bin/render-build.sh
git commit -m "chore: restore normal build after DB reset"
git push origin main

echo ""
echo "✅ Pronto! Banco resetado e build normal restaurado."
echo "   O Render vai fazer mais um deploy (normal, sem reset)."
