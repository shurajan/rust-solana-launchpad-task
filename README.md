# Solana Mini Launchpad

Учебный мини-лаунчпад на Solana + Anchor: два on-chain контракта (SOL/USD oracle и token minter), Rust backend для обновления цены и прослушки событий, а также Remix фронтенд (папка `frontend/`).

## Структура
- `program/` — Anchor workspace  
  - `programs/sol_usd_oracle` — хранит цену SOL/USD (decimals = 6)  
  - `programs/token_minter` — минтит SPL токены за комиссию в SOL, используя цену из oracle  
  - `tests/` — Anchor TS тесты  
- `backend/` — Rust сервис, который обновляет цену и слушает события `TokenCreated`
- `frontend/` — Remix hello-world (React Router)

## Быстрый старт (локально)

1. **Validator**: запустить `solana-test-validator` (или `make validator`). Для отображения имени, тикера и картинки токена в кошельке используйте валидатор с клоном Metaplex: `make validator-metaplex` (клон программы Token Metadata с mainnet). Убедитесь, что `~/.config/solana/id.json` есть и профинансирован (`solana airdrop 1000` при необходимости).

2. **Программы**: собрать и задеплоить (ID программ берутся из keypair в `program/target/deploy/`; при первом деплое выполните `anchor keys sync`, затем пересоберите):
   ```bash
   make build
   make deploy
   ```

3. **Инициализация**: один раз после деплоя инициализировать oracle и minter (скрипт выведет `ORACLE_STATE_PUBKEY` для `.env`):
   ```bash
   make init
   ```

## Деплой на Devnet

На фронте есть переключатель **Localnet / Devnet**. Для тестов на devnet:

1. Переключить CLI на devnet и пополнить кошелёк:
   ```bash
   solana config set --url devnet
   solana airdrop 2
   ```

2. Собрать и задеплоить на devnet:
   ```bash
   make deploy-devnet
   ```

3. Инициализировать оракул и минтер на devnet (один раз):
   ```bash
   make init-devnet
   ```

4. В приложении выбрать сеть **Devnet**, в кошельке переключиться на Devnet — можно минтить. На devnet Metaplex уже есть, картинка в кошельке может отображаться (если URI доступен по HTTPS).

4. **Backend**: скопировать `backend/.env.example` в `backend/.env`, подставить `ORACLE_STATE_PUBKEY` из вывода init-скрипта. Путь `BACKEND_KEYPAIR_PATH` поддерживает `~`:
   ```bash
   cd backend
   cargo run
   ```
   Сервис будет периодически вызывать `update_price` и слушать события `TokenCreated`, выводя их в stdout в JSON.

5. **Фронтенд** (опционально):
   ```bash
   cd frontend
   npm install && npm run dev
   ```
  Открыть http://localhost:7001.

6. **Тесты** (LiteSVM, без сети):

   Быстрый путь — всё через `make` (проверит версию Node, соберёт с `--ignore-keys`, запустит тесты):
   ```bash
   nvm use 20        # см. program/.nvmrc; make не может переключить Node сам
   make test         # = check-node + build-test + запуск mocha
   ```
   `make prereqs` отдельно проверит Node и поставит зависимости `program/`.

   Что делают эти шаги вручную и почему — ниже.

   Предварительные требования (иначе тесты не запустятся):
   - **Node.js 20 LTS.** На Node 18 и Node 24+ старый стек mocha/ts-node падает при загрузке ESM-тестов (`"type": "module"` + `import.meta.url`). Зафиксируйте версию:
     ```bash
     nvm install 20 && nvm use 20   # см. .nvmrc
     ```
   - **Зависимости.** `package.json` уже включает `ts-node@10.9.2` (у него есть ESM-loader; штатный `ts-mocha` тянет несовместимый `ts-node@7`). Достаточно установить:
     ```bash
     cd program && yarn install
     ```
   - **Сборка программ с `--ignore-keys`.** Каталог `target/` в `.gitignore`, поэтому после клона `anchor build` генерирует новые keypair'ы и их ID не совпадают с зашитыми в исходниках/тестах (`4cuv…`, `E5er…`). Тесты грузят `.so` по этим фиксированным ID, поэтому ключи синхронизировать **не нужно** — просто пропускаем проверку:
     ```bash
     anchor build --ignore-keys
     ```

   Запуск тестов (после `anchor build --ignore-keys`):
   ```bash
   cd program
   anchor test            # или: anchor run test
   ```
   Или `anchor run litesvm` — то же самое, только тесты `tests/*.litesvm.ts`.

   > Скрипты `test`/`litesvm` в `Anchor.toml` запускают `mocha` через loader `ts-node/esm`
   > напрямую, а не `ts-mocha`, так как последний несовместим с ESM.

## Переменные окружения для backend

См. `backend/.env.example`. Основные:
- `SOLANA_RPC_HTTP`, `SOLANA_RPC_WS` — RPC локального валидатора или devnet/mainnet.
- `ORACLE_PROGRAM_ID`, `MINTER_PROGRAM_ID` — из `anchor keys list` (после деплоя).
- `ORACLE_STATE_PUBKEY` — PDA от seed `"oracle_state"`; выводится скриптом `program/scripts/init-local.js`.
- `BACKEND_KEYPAIR_PATH` — keypair администратора оракула (поддерживается `~`).
- Опционально: `MOCK_PRICE`, `PRICE_API_URL`, `PRICE_POLL_INTERVAL_SEC`.

## Метаданные токена (Metaplex)

При минте можно передать `name`, `symbol` и `uri` — контракт создаёт запись Metaplex Token Metadata (имя, тикер, картинка в кошельке). Если передать пустое имя, метаданные не создаются (подходит для localnet без Metaplex). Для отображения в кошельке поднимайте валидатор с клоном Metaplex: `make validator-metaplex`, затем деплой и `init` как обычно.

## Основные ограничения
- Все вычисления комиссии — integer math, `fee_lamports = mint_fee_usd * LAMPORTS_PER_SOL / price`.
- Oracle price и mint_fee_usd хранятся с точностью 10^6.
- Доступ к `update_price` только у oracle admin (backend keypair).
- `mint_token` падает, если `price == 0` или fee/supply некорректны.


---

## Порядок запуска (локально)

1. `solana-test-validator`
2. `cd program && anchor build && anchor deploy --provider.cluster localnet`
3. `cd program && node scripts/init-local.js` — скопировать `ORACLE_STATE_PUBKEY` в `backend/.env`
4. `cd backend && cargo run`
5. `cd frontend && npm run dev` — открыть в браузере и покликать.
