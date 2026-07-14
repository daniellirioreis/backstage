#!/bin/bash
# deploy-portfolio.sh
# Uso: bash deploy-portfolio.sh "descrição da alteração"

MSG=${1:-"portfolio: atualização"}

echo "📦 Commitando alterações..."
git add public/portfolio/
git commit -m "$MSG" || echo "   (nada novo para commitar)"

echo "🚀 Publicando no GitHub Pages..."
git subtree push --prefix public/portfolio origin gh-pages

echo ""
echo "✅ Pronto! Acesse em alguns instantes:"
echo "   https://daniellirioreis.github.io/backstage/"
