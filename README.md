# Solana Mini Launchpad

Учебный мини-лаунчпад на Solana + Anchor: два on-chain контракта (SOL/USD oracle и token minter), Rust backend для обновления цены и прослушки событий, а также Remix фронтенд (папка `frontend/`).

## Структура
- `program/` — Anchor workspace  
  - `programs/sol_usd_oracle` — хранит цену SOL/USD (decimals = 6)  
  - `programs/token_minter` — минтит SPL токены за комиссию в SOL, используя цену из oracle  
  - `tests/` — Anchor TS тесты  
- `backend/` — Rust сервис, который обновляет цену и слушает события `TokenCreated`
- `frontend/` — Remix UI для минта: подключение кошелька (Phantom/Solflare), переключатель Localnet/Devnet, форма минта

## Быстрый старт (локально)

1. **Validator**: запустить `solana-test-validator` (или `make validator`). Для отображения имени, тикера и картинки токена в кошельке используйте валидатор с клоном Metaplex: `make validator-metaplex` (клон программы Token Metadata с mainnet). Убедитесь, что `~/.config/solana/id.json` есть и профинансирован (`solana airdrop 1000 --url localhost` при необходимости — явный `--url`, чтобы не попасть на devnet, если CLI переключён туда).

2. **Программы**: собрать и задеплоить. ID программ берутся из keypair в `program/target/deploy/` (в git не хранятся). Если после свежего клона сгенерировались новые keypair'ы, выполните `anchor keys sync` и пересоберите — но учтите: sync перепишет `declare_id!` и `Anchor.toml`, после чего нужно обновить те же ID, зашитые в `program/tests/*.ts`, `program/scripts/*.js`, `frontend/app/config.ts` и `backend/.env` (сейчас везде `qgMx…`/`HZ8…`):
   ```bash
   make build
   make deploy
   ```

3. **Инициализация**: один раз после деплоя инициализировать oracle и minter (скрипт выведет `ORACLE_STATE_PUBKEY` для `.env`):
   ```bash
   make init
   ```

4. **Backend**: скопировать `backend/.env.example` в `backend/.env`, подставить `ORACLE_STATE_PUBKEY` из вывода init-скрипта. Путь `BACKEND_KEYPAIR_PATH` поддерживает `~`:
   ```bash
   cd backend
   cargo run
   ```
   Сервис будет периодически вызывать `update_price` и слушать события `TokenCreated`, выводя их в stdout в JSON.

5. **Фронтенд**:
   ```bash
   cd frontend
   npm install && npm run dev
   ```
   Открыть http://localhost:7001 (порт задан в `frontend/package.json`; прод-вариант `npm run build && npm run start` — тоже 7001).

6. **Тесты** (LiteSVM, без сети):

   Требования:
   - **Node.js ≥ 23.6** (рекомендуется Node 24 LTS или новее). Тесты — TypeScript ESM, современный Node исполняет их нативно (type stripping), без ts-node. Версия проверяется автоматически при `yarn install` (поле `engines` в `program/package.json`).
   - Зависимости: `make install` (или `cd program && yarn install`).
   - Собранные программы: тесты грузят `.so` из `program/target/deploy/` по ID, зашитым в исходниках (`qgMx…`, `HZ8…`). Если `anchor build` падает с «Program ID mismatch» (keypair'ы в `target/deploy/` сгенерированы заново после клона), соберите с пропуском проверки ключей — синхронизировать ключи для тестов **не нужно**:
     ```bash
     cd program && anchor build --ignore-keys
     ```

   Запуск:
   ```bash
   make test          # или: cd program && anchor run test
   ```
   Или `anchor run litesvm` — то же самое, только тесты `tests/*.litesvm.ts`.

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

4. **Backend для devnet** (опционально): `make backend-devnet` — подставит devnet RPC автоматически, остальное возьмёт из `backend/.env`.

5. В приложении выбрать сеть **Devnet**, в кошельке переключиться на Devnet — можно минтить. На devnet Metaplex уже есть, картинка в кошельке может отображаться (если URI доступен по HTTPS).

Если публичный RPC devnet обрывает деплой («Blockhash expired»), используйте `./deploy-devnet-helius.sh <HELIUS_API_KEY>` — деплой через Helius RPC с приоритетной комиссией и ретраями; `solana config` при этом не меняется.

## Devnet: доказательства деплоя

Программы задеплоены и инициализированы на devnet (полный лог — в `deploy.log`).

### Программы

| Программа | Program ID | Deploy tx | Слот |
|---|---|---|---|
| `sol_usd_oracle` | [`qgMxYoiKq6imJNLcnJCGsEZFNqCk7jkpEPPrVigwE55`](https://explorer.solana.com/address/qgMxYoiKq6imJNLcnJCGsEZFNqCk7jkpEPPrVigwE55?cluster=devnet) | [`3mmqhy…95Ciu`](https://explorer.solana.com/tx/3mmqhyMSuVCMU9QtfEVuJJJ2xmMq9FjscK5KVxqV4Hcwa7krr92pNivBuDoADfD18RgamJ9VqDDtCW38ian95Ciu?cluster=devnet) | 475979776 |
| `token_minter` | [`HZ8ztnxaaLYgGb33c4t4mp5pxHELn4kN8xbxfG67sdCG`](https://explorer.solana.com/address/HZ8ztnxaaLYgGb33c4t4mp5pxHELn4kN8xbxfG67sdCG?cluster=devnet) | [`4jPZae…1W4Dc`](https://explorer.solana.com/tx/4jPZaeqoy3zsf4uBSpKruGib9EXSWSrUyxPQXDmbHgYSVRnxZbdf62Gbbfww3Zd6eEFXbugYovTGnUCGKoX1W4Dc?cluster=devnet) | 475984704 |

Upgrade authority обеих программ: [`4zFz4k8BjQ2GXZ9unqAefT3f8ELEMb85yAFzoHtGkHpi`](https://explorer.solana.com/address/4zFz4k8BjQ2GXZ9unqAefT3f8ELEMb85yAFzoHtGkHpi?cluster=devnet).

### Инициализация (`make init-devnet`)

| Шаг | Транзакция |
|---|---|
| `initialize_oracle` | [`szFUkt…zGnpC`](https://explorer.solana.com/tx/szFUktfEWpYmFqVagDpvWzEY3exaMY8tf2mJ81KJMpPX6f5MK7r2fa7CpvxWCg7HDyhkPwYkVWrBYRfUkkzGnpC?cluster=devnet) |
| `update_price` (цена $120) | [`44ymQ4…J2ELL`](https://explorer.solana.com/tx/44ymQ4Z4JKLEaYSPStDmaeSRZrDaQX9jc28MgQy7f82UB2wks167fw6bzqG8DXg4h3jNS98yWerw6BEoTk4J2ELL?cluster=devnet) |
| `initialize_minter` | [`5DnWZJ…JEfMr`](https://explorer.solana.com/tx/5DnWZJTc3NMnK28su1fJmdRVMuLB5xWFSXgfkVofxfVACusZJdgEhxVF7CVHphNbY8g9kyvFNhXkyBwfGNvJEfMr?cluster=devnet) |

Oracle state PDA: [`GpkvPnhPKdW7CmccSjgumyySro2Yt3e5tBe3PEcpbDPc`](https://explorer.solana.com/address/GpkvPnhPKdW7CmccSjgumyySro2Yt3e5tBe3PEcpbDPc?cluster=devnet).

### Минты через UI

| # | Транзакция |
|---|---|
| 1 | [`3732Kb…euUt2`](https://explorer.solana.com/tx/3732KbbnY1xXguJsGtVMa8hGnarxaqJ4WA8oWaxzAc3iVjb3vjrUrioiTRirTiTB6Zhco9iB5N1B1eYSnGqeuUt2?cluster=devnet) |
| 2 | [`5eqD2F…KrriB`](https://explorer.solana.com/tx/5eqD2FW6eEqfresW4a9VTj3DrzdG1AJaUyCnymAuAzrrVbgrkSwSDUuqvhDE8pbQAFGD3QLMzRqgLnPXA2BKrriB?cluster=devnet) |
| 3 | [`4FnuFS…cJFDFG`](https://explorer.solana.com/tx/4FnuFS97u5tN8zxMnbaQ1ounF3xXHbAtVfpcjkDcRD9GeVAFT5AAG3r6LmxvmKFQBdgiabNZwDU18QZ4kfcJFDFG?cluster=devnet) |

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
5. `cd frontend && npm run dev` — открыть http://localhost:7001 и покликать.
