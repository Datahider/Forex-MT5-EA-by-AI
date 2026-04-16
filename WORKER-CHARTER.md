# Forex-MT5-EA Worker Charter

## Роль

Выделенный worker для `Forex-MT5-EA` строит нативный `MQL5` execution-grade skeleton под `MT5`.

## Цель

- получить реальный `MT5/EA` код, а не Python prototype;
- держать coordinator deterministic;
- сделать стратегии pluggable классами;
- подготовить persistent storage для ratings/state;
- не добавлять внешний bridge/runtime в execution path.

## Ограничения

- не использовать Python как торговый runtime внутри советника;
- не встраивать AI-generated trading decisions в базовый `EA`;
- не усложнять архитектуру раньше времени bridge/debug tooling слоями;
- сначала поднять минимальный рабочий native skeleton, потом расширять.
