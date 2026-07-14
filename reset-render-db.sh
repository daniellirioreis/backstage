#!/bin/bash
# reset-render-db.sh
# Uso: bash reset-render-db.sh
#
# Como funciona:
#   1. Você adiciona RESET_DB=true nas env vars do serviço no Render dashboard
#   2. Roda este script (faz push para triggerar o deploy)
#   3. Render detecta RESET_DB=true e zera o banco
#   4. Após o deploy, você remove RESET_DB do Render dashboard

set -e

echo "⚠️  ATENÇÃO: isso vai apagar todos os dados de produção no Render!"
echo ""
echo "Antes de continuar, você precisa:"
echo "   1. Acessar https://dashboard.render.com → serviço 'backstage' → Environment"
echo "   2. Adicionar a variável:  RESET_DB = true"
echo "   3. Salvar (NÃO fazer deploy ainda)"
echo ""
read -p "Variável RESET_DB=true adicionada no Render? (s/N) " confirm
[[ "$confirm" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }

echo ""
echo "🚀 Fazendo push para triggerar o deploy de reset..."
git push origin main

echo ""
echo "⏳ Deploy de reset iniciado! Acompanhe em https://dashboard.render.com"
echo "   O build vai detectar RESET_DB=true e zerar o banco automaticamente."
echo ""
echo "Quando o deploy finalizar:"
echo "   1. Acesse o Render dashboard → Environment"
echo "   2. REMOVA a variável RESET_DB"
echo "   3. Salve (isso vai triggerar mais um deploy normal, sem reset)"
echo ""
echo "✅ Pronto! Banco zerado com dados iniciais: planos, perfis e admin."
