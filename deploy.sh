#!/bin/bash
# deploy.sh — Publica o Backstage no Render
# Uso:
#   bash deploy.sh staging      → sobe para homologação
#   bash deploy.sh production   → merge staging→main e sobe para produção

set -e

ENV=${1:-""}

if [ -z "$ENV" ]; then
  echo "❌ Informe o ambiente: staging ou production"
  echo "   Uso: bash deploy.sh staging"
  echo "        bash deploy.sh production"
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$ENV" = "staging" ]; then
  echo "🔀 Publicando em HOMOLOGAÇÃO..."

  # Garante que staging existe
  git checkout staging 2>/dev/null || git checkout -b staging

  # Traz as alterações da branch atual
  git merge "$CURRENT_BRANCH" --no-edit

  git push origin staging

  echo ""
  echo "✅ Deploy de homologação enviado!"
  echo "   🔗 https://backstage-staging.onrender.com"
  echo "   ⚠️  O Render pode levar alguns minutos para concluir o build."
  echo ""

  # Volta para a branch original
  git checkout "$CURRENT_BRANCH"

elif [ "$ENV" = "production" ]; then
  echo "🚀 Publicando em PRODUÇÃO..."

  read -p "   Tem certeza? Isso vai atualizar o site em produção. (s/N) " confirm
  if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "   Cancelado."
    exit 0
  fi

  # Garante que está na main
  git checkout main

  # Traz as alterações do staging
  git merge staging --no-edit

  git push origin main

  echo ""
  echo "✅ Deploy de produção enviado!"
  echo "   🔗 https://backstage.onrender.com"
  echo "   ⚠️  O Render pode levar alguns minutos para concluir o build."
  echo ""

else
  echo "❌ Ambiente inválido: '$ENV'"
  echo "   Use: staging ou production"
  exit 1
fi
