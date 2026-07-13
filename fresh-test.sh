./#!/usr/bin/env bash
# Симуляция «свежего клона»: удаляет все генерируемые артефакты и прогоняет
# полный цикл: make install -> anchor build -> make test -> backend cargo test.
#
# Использование:
#   ./fresh-test.sh                # полный цикл
#   ./fresh-test.sh --skip-backend # без backend (быстрее: не пересобирает Rust-сервис)
#
# Не трогает: backend/.env и другие пользовательские файлы.

set -euo pipefail
cd "$(dirname "$0")"

SKIP_BACKEND=0
[[ "${1:-}" == "--skip-backend" ]] && SKIP_BACKEND=1

step() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }

step "Проверка окружения"
node --version
yarn --version
anchor --version

step "Очистка генерируемых артефактов (как после свежего клона)"
rm -rf program/node_modules program/target program/Cargo.lock
rm -rf frontend/node_modules
if [[ $SKIP_BACKEND -eq 0 ]]; then
  rm -rf backend/target backend/Cargo.lock
fi

step "make install"
make install

step "anchor build --ignore-keys (собирает .so с ID, зашитыми в исходниках)"
(cd program && anchor build --ignore-keys)

step "make test (LiteSVM)"
make test

if [[ $SKIP_BACKEND -eq 0 ]]; then
  step "backend: cargo test"
  (cd backend && cargo test)
fi

step "Готово: все тесты прошли"
