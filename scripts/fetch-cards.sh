#!/usr/bin/env bash
# Baixa os cards de estatistica e grava em cards/.
# Os servicos publicos aplicam rate limit e respondem 200 com um SVG de
# erro, entao cada resposta e validada antes de sobrescrever o arquivo.
# Card que falhar em todas as tentativas mantem a versao do dia anterior.
set -uo pipefail

USER=ThomasTonho
THEME=tokyonight
SUMMARY=https://github-profile-summary-cards.vercel.app/api/cards
STREAK=https://streak-stats.demolab.com

declare -A CARDS=(
  [profile-details]="$SUMMARY/profile-details?username=$USER&theme=$THEME"
  [stats]="$SUMMARY/stats?username=$USER&theme=$THEME"
  [most-commit-language]="$SUMMARY/most-commit-language?username=$USER&theme=$THEME"
  [repos-per-language]="$SUMMARY/repos-per-language?username=$USER&theme=$THEME"
  [streak]="$STREAK/?user=$USER&theme=$THEME&hide_border=true"
)

mkdir -p cards
failed=0

for name in "${!CARDS[@]}"; do
  for attempt in 1 2 3 4 5; do
    tmp=$(mktemp)
    code=$(curl -sL --max-time 30 -o "$tmp" -w '%{http_code}' "${CARDS[$name]}")

    if [ "$code" = 200 ] \
      && head -c 200 "$tmp" | grep -qi '<svg' \
      && ! grep -qiE "rate limited|can't fetch|unavailable|DEPLOYMENT_PAUSED" "$tmp"; then
      mv "$tmp" "cards/$name.svg"
      echo "$name: ok"
      break
    fi

    rm -f "$tmp"
    if [ "$attempt" = 5 ]; then
      echo "$name: falhou (HTTP $code), mantendo versao anterior"
      [ -f "cards/$name.svg" ] || failed=1
    else
      sleep 30
    fi
  done
done

# Só quebra o build se algum card nunca existiu; card velho serve.
exit $failed
