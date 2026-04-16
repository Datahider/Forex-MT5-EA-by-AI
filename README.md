# Forex-MT5-EA

Отдельный проект под `MQL5-native` советник для `MT5`.

## Зачем он нужен

`Forex-MT5-Core` остался Python prototype/spec и не является исполняемым советником.

Этот проект нужен для реальной нативной реализации:

- `EA` и coordinator работают прямо в `MT5`;
- стратегии оформляются как pluggable `MQL5` классы;
- decisions, arbitration, ratings и storage живут внутри терминального execution path;
- внешний AI, если когда-то появится, остаётся только supervisory layer вне базового ядра.

## Ближайшая цель

Собрать первый `MQL5-native` execution-capable slice:

- базовые domain/contracts;
- pluggable strategy interface;
- deterministic coordinator;
- filesystem storage для ratings/state;
- индикаторные стратегии на стандартных `MQL5` handles;
- минимальный `EA` entrypoint.

## Что уже добавлено

Первый нативный `MQL5` source slice теперь лежит в структуре `MQL5/...` и не использует `Python runtime` или какой-либо bridge в execution path.

Структура:

- `EA-by-AI.mq5` - entrypoint советника в корне MetaEditor project, который собирает `StrategyContext`, вызывает coordinator, строит netting execution plan и при разрешённом runtime выполняет реальный `OrderSend`.
- `Include/Domain/StrategyContracts.mqh` - domain/contracts для `strategy id`, `decision types`, `strategy decision`, `strategy rating`.
- `Include/Strategies/IStrategy.mqh` - pluggable strategy interface.
- `Include/Strategies/StrategyBase.mqh` - базовый класс стратегии с примитивным persistent state.
- `Include/Strategies/EmaTrendStrategy.mqh` - trend-following стратегия на `EMA(21/55)` с фильтром `ADX(14)`.
- `Include/Strategies/RsiMeanReversionStrategy.mqh` - mean-reversion стратегия на `RSI(14)` и возврате внутрь `Bollinger Bands(20, 2.0)`.
- `Include/Strategies/RangeBreakoutStrategy.mqh` - breakout стратегия по пробою `20-bar` диапазона с фильтром на `ATR(14)` и форме свечи.
- `Include/Coordination/DeterministicCoordinator.mqh` - deterministic coordinator, который принимает список стратегий и выбирает победителя детерминированно.
- `Include/Storage/FileStateStore.mqh` - файловый storage слой на `MT5 File API` для ratings/state.
- `Include/Domain/ExecutionContracts.mqh` - domain/contracts для `execution intent`, `target exposure`, `risk status`, `execution plan`.
- `Include/Risk/DeterministicRiskGate.mqh` - deterministic risk gate, который валидирует intent и режет unsafe/impossible execution до planner'а.
- `Include/Execution/NettingExecutionPlanner.mqh` - planner для `netting`-style exposure transitions `hold/open/increase/reduce/close/flip`.
- `Include/Execution/Mt5TradeExecutor.mqh` - guarded execution layer поверх `MqlTradeRequest/MqlTradeResult`, который переводит approved plan в реальный `OrderSend`.

## Принципы execution slice

- `EA` не содержит внешнего bridge/runtime и использует стандартный `MT5 trade engine`.
- Все решения стратегий проходят через deterministic coordinator.
- После coordinator решение превращается в `execution intent`, проходит через deterministic `risk gate`, затем собирается `netting execution plan`, и только после этого возможен реальный `OrderSend`.
- Ratings и strategy state сохраняются через `FILE_COMMON`, чтобы их можно было использовать как persistent layer внутри терминала.
- Стратегии используют только стандартные `MQL5` индикаторы и считают сигнал только на первом тике нового бара по закрытым барам, чтобы не дублировать решения на каждом тике.
- Live execution защищён явным input guard: по умолчанию `InpEnableLiveExecution=false`, но в `MT5 Strategy Tester` тот же execution path доступен без отдельной симуляции.

## Текущие стратегии

- `EMA Trend` даёт `BUY/SELL` только на новом закрытом баре, когда `EMA(21)` пересекает `EMA(55)`, а `ADX(14)` остаётся выше минимального порога силы тренда.
- `RSI Mean Reversion` ищет редкий возврат из экстремума: один закрытый бар должен уйти за внешнюю полосу Bollinger вместе с экстремальным `RSI`, а следующий закрытый бар должен вернуться внутрь диапазона вместе с нормализацией RSI.
- `Range Breakout` даёт сигнал только если закрытый бар пробивает максимум или минимум последних `20` закрытых баров, закрывается у края своей свечи и выносит диапазон хотя бы на долю текущего `ATR(14)`.

Coordinator по-прежнему делает deterministic arbitration: сначала сравнивает `weight_bps * confidence_bps`, затем `confidence_bps`, затем `strategy_id`.

## Новый flow

`OnTick` теперь проходит через следующую цепочку:

- build `StrategyContext`;
- получить coordinator decision;
- собрать snapshot текущей `netting`-позиции по символу;
- преобразовать decision в `ExecutionIntent`;
- прогнать intent через deterministic `RiskGate`;
- собрать `ExecutionPlan` для netting exposure transition;
- выполнить `Mt5TradeExecutor`, который либо делает `no-op`, либо шлёт реальный `OrderSend` по текущему символу;
- залогировать `decision`, `risk status`, `execution plan`, а также `execution request/result status`.

Для netting-модели текущего символа поддерживаются базовые действия:

- `HOLD`/`no-op`;
- `BUY exposure` из flat, increase long, reduce short, flip short->long;
- `SELL exposure` из flat, increase short, reduce long, flip long->short;
- `EXIT to flat` через противоположный market deal на текущий объём.

Это не внутренний simulated tester: в tester используется тот же реальный execution layer на `OrderSend`, что и в live.

## Layout For MetaEditor

Структура выровнена под MetaEditor project directory:

- главный `EA` лежит в корне репозитория как `EA-by-AI.mq5`;
- все внутренние зависимости лежат рядом в `Include/...`;
- include-пути сделаны относительными, чтобы проект можно было просто `git pull` в папку проекта без ручного перекладывания в `MQL5/Experts` и `MQL5/Include`.

`EA-by-AI.mqproj` лучше один раз создать в MetaEditor на целевой машине и затем закоммитить в корень этого же репозитория, чтобы IDE project file тоже жил рядом с главным `EA`.

## Как развивать дальше

- расширить `StrategyContext` рыночными данными и risk constraints;
- расширить execution policy поверх текущего `OrderSend` слоя, не ломая deterministic coordinator/risk pipeline;
- подключить versioned storage format для ratings/state, когда появится реальная эволюция схемы.
