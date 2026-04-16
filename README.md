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

Собрать первый `MQL5-native` skeleton:

- базовые domain/contracts;
- pluggable strategy interface;
- deterministic coordinator;
- filesystem storage для ratings/state;
- dummy strategies для wiring;
- минимальный `EA` entrypoint.

## Что уже добавлено

Первый нативный `MQL5` source slice теперь лежит в структуре `MQL5/...` и не использует `Python runtime` или какой-либо bridge в execution path.

Структура:

- `EA-by-AI.mq5` - skeleton entrypoint советника в корне MetaEditor project, который собирает `StrategyContext`, вызывает coordinator и логирует итоговое решение.
- `Include/ForexMt5EA/Domain/StrategyContracts.mqh` - domain/contracts для `strategy id`, `decision types`, `strategy decision`, `strategy rating`.
- `Include/ForexMt5EA/Strategies/IStrategy.mqh` - pluggable strategy interface.
- `Include/ForexMt5EA/Strategies/StrategyBase.mqh` - базовый класс стратегии с примитивным persistent state.
- `Include/ForexMt5EA/Strategies/DummyTrendStrategy.mqh` - dummy strategy для wiring.
- `Include/ForexMt5EA/Strategies/DummyMeanReversionStrategy.mqh` - вторая dummy strategy для арбитрации.
- `Include/ForexMt5EA/Coordination/DeterministicCoordinator.mqh` - deterministic coordinator, который принимает список стратегий и выбирает победителя детерминированно.
- `Include/ForexMt5EA/Storage/FileStateStore.mqh` - файловый storage слой на `MT5 File API` для ratings/state.
- `Include/ForexMt5EA/Domain/ExecutionContracts.mqh` - domain/contracts для `execution intent`, `target exposure`, `risk status`, `execution plan`.
- `Include/ForexMt5EA/Risk/DeterministicRiskGate.mqh` - deterministic risk gate, который валидирует intent и режет unsafe/impossible execution до planner'а.
- `Include/ForexMt5EA/Execution/DryRunExecutionPlanner.mqh` - dry-run planner для `netting`-style exposure transitions без реальной отправки ордеров.

## Принципы skeleton

- `EA` не содержит реальную торговую логику и не шлёт ордера.
- Все решения стратегий проходят через deterministic coordinator.
- После coordinator решение превращается в `execution intent`, проходит через deterministic `risk gate` и только потом собирается в dry-run `execution plan`.
- Ratings и strategy state сохраняются через `FILE_COMMON`, чтобы их можно было использовать как persistent layer внутри терминала.
- Dummy strategies нужны только для wiring, чтобы дальше можно было заменять их реальными `MQL5` классами без смены каркаса.

## Новый flow

`OnTick` теперь проходит через следующую цепочку:

- build `StrategyContext`;
- получить coordinator decision;
- собрать snapshot текущей `netting`-позиции по символу;
- преобразовать decision в `ExecutionIntent`;
- прогнать intent через deterministic `RiskGate`;
- собрать dry-run `ExecutionPlan`;
- залогировать `decision`, `risk status` и итоговый `execution plan`.

Это остаётся безопасным skeleton'ом следующего слоя: planner умеет только моделировать `hold/open/increase/reduce/close/flip`, но не вызывает `OrderSend`.

## Layout For MetaEditor

Структура выровнена под MetaEditor project directory:

- главный `EA` лежит в корне репозитория как `EA-by-AI.mq5`;
- все внутренние зависимости лежат рядом в `Include/ForexMt5EA/...`;
- include-пути сделаны относительными, чтобы проект можно было просто `git pull` в папку проекта без ручного перекладывания в `MQL5/Experts` и `MQL5/Include`.

`EA-by-AI.mqproj` лучше один раз создать в MetaEditor на целевой машине и затем закоммитить в корень этого же репозитория, чтобы IDE project file тоже жил рядом с главным `EA`.

## Как развивать дальше

- заменить dummy strategies реальными signal generators;
- расширить `StrategyContext` рыночными данными и risk constraints;
- добавить execution/risk слой после coordinator, не ломая native execution path;
- подключить versioned storage format для ratings/state, когда появится реальная эволюция схемы.
