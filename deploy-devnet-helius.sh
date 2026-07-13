#!/usr/bin/env bash
# Deploy both programs to devnet through a Helius RPC endpoint.
#
# Usage:
#   ./deploy-devnet-helius.sh <HELIUS_API_KEY>
#   HELIUS_API_KEY=xxx ./deploy-devnet-helius.sh
#
# The Helius URL is passed per-command via --url, so your `solana config`
# is never changed and nothing needs to be reverted afterwards.
set -euo pipefail

HELIUS_API_KEY="${1:-${HELIUS_API_KEY:-}}"
if [ -z "$HELIUS_API_KEY" ]; then
  echo "Ошибка: нужен API-ключ Helius (бесплатно на https://dev.helius.xyz)." >&2
  echo "Использование: ./deploy-devnet-helius.sh <HELIUS_API_KEY>" >&2
  exit 1
fi

RPC_URL="https://devnet.helius-rpc.com/?api-key=${HELIUS_API_KEY}"
ORACLE_ID="qgMxYoiKq6imJNLcnJCGsEZFNqCk7jkpEPPrVigwE55"
MINTER_ID="HZ8ztnxaaLYgGb33c4t4mp5pxHELn4kN8xbxfG67sdCG"
DEPLOY_FLAGS=(--url "$RPC_URL" --use-rpc --with-compute-unit-price 10000 --max-sign-attempts 100)

cd "$(dirname "$0")"

echo "=== Текущий solana config (не меняется скриптом) ==="
solana config get | grep "RPC URL"

echo
echo "=== Баланс кошелька на devnet ==="
solana balance --url "$RPC_URL"

echo
echo "=== Закрываем зависшие deploy-буферы (возврат ренты) ==="
solana program close --buffers --url "$RPC_URL" || true

echo
echo "=== anchor build ==="
(cd program && CARGO_TARGET_DIR="$(pwd)/target" anchor build)

echo
echo "=== Деплой sol_usd_oracle ($ORACLE_ID) ==="
solana program deploy program/target/deploy/sol_usd_oracle.so \
  --program-id program/target/deploy/sol_usd_oracle-keypair.json \
  "${DEPLOY_FLAGS[@]}"

echo
echo "=== Деплой token_minter ($MINTER_ID) ==="
solana program deploy program/target/deploy/token_minter.so \
  --program-id program/target/deploy/token_minter-keypair.json \
  "${DEPLOY_FLAGS[@]}"

echo
echo "=== Проверка ==="
solana program show "$ORACLE_ID" --url "$RPC_URL"
solana program show "$MINTER_ID" --url "$RPC_URL"

echo
echo "=== Готово. Дальше: make init-devnet ==="
