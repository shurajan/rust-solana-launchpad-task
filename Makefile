# Минимум команд для запуска проекта

.PHONY: install check-node prereqs validator validator-metaplex build build-test deploy deploy-devnet deploy-oracle-devnet deploy-minter-devnet init init-devnet deploy-oracle deploy-minter backend backend-devnet frontend kill-frontend test

install:
	cd program && yarn install
	cd frontend && npm install

# Проверка версии Node: тесты требуют Node 20 (см. program/.nvmrc).
# nvm — это shell-функция и недоступна внутри make, поэтому здесь только проверка.
check-node:
	@node -e 'var v=+process.versions.node.split(".")[0]; if (v!==20){console.error("\n[!] Требуется Node 20 (сейчас "+process.version+").\n    Выполните: nvm install 20 && nvm use 20   (см. program/.nvmrc)\n"); process.exit(1);} else {console.log("Node "+process.version+" — ок");}'

# Установить всё необходимое для тестов: версия Node + зависимости program/
prereqs: check-node
	cd program && yarn install

# Обычный локальный валидатор (без Metaplex)
validator:
	solana-test-validator

# Валидатор с клоном Metaplex Token Metadata (для отображения имени/тикера/картинки в кошельке)
validator-metaplex:
	solana-test-validator --clone-upgradeable-program metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s --url https://api.mainnet-beta.solana.com

build:
	cd program && anchor build

# Сборка для тестов: target/ в .gitignore, после клона anchor генерирует
# новые keypair'ы, ID которых не совпадают с зашитыми в исходниках/тестах.
# Тесты грузят .so по фиксированным ID, поэтому пропускаем проверку ключей.
build-test:
	cd program && anchor build --ignore-keys

# Деплоит оба контракта на localnet (сначала запусти make validator в другом терминале)
deploy: build
	cd program && anchor deploy --provider.cluster localnet

# Devnet: переключись (solana config set-url devnet), пополни (solana airdrop 2), затем деплой обоих контрактов:
deploy-devnet: deploy-oracle-devnet deploy-minter-devnet

# Devnet: деплой только оракула или только минтера
deploy-oracle-devnet: build
	cd program && anchor deploy --program-name sol_usd_oracle --provider.cluster devnet

deploy-minter-devnet: build
	cd program && anchor deploy --program-name token_minter --provider.cluster devnet

# Инициализация оракула и минтера (localnet по умолчанию)
init:
	cd program && node scripts/init-local.js

# Инициализация на devnet (после make deploy-devnet)
init-devnet:
	cd program && RPC_URL=https://api.devnet.solana.com node scripts/init-local.js

# Localnet: деплой только оракула или только минтера (сначала make validator)
deploy-oracle: build
	cd program && anchor deploy --program-name sol_usd_oracle --provider.cluster localnet

deploy-minter: build
	cd program && anchor deploy --program-name token_minter --provider.cluster localnet

# Backend для localnet (читает backend/.env; нужны SOLANA_RPC_HTTP, SOLANA_RPC_WS)
backend:
	cd backend && cargo run

# Backend для devnet (подставляет RPC devnet; ORACLE_STATE_PUBKEY и т.д. из .env)
backend-devnet:
	cd backend && SOLANA_RPC_HTTP=https://api.devnet.solana.com SOLANA_RPC_WS=wss://api.devnet.solana.com cargo run

# Освободить порт 7001 (если занят старым процессом фронта)
kill-frontend:
	-lsof -ti:7001 | xargs kill 2>/dev/null || true

frontend: kill-frontend
	cd frontend && npm run dev

# Тесты (LiteSVM, без сети). Требуют Node 20 и собранные .so (build-test).
# ts-mocha тянет несовместимый ts-node@7, поэтому запускаем mocha через loader ts-node/esm.
test: check-node build-test
	cd program && NODE_OPTIONS="--loader ts-node/esm" TS_NODE_PROJECT="./tsconfig.json" node_modules/.bin/mocha -t 1000000 "tests/**/*.ts"
