# PROJECT

## Name

Forex-MT5-EA

## Status

bootstrap

## Purpose

Нативный `MQL5` проект для советника под `MT5`, без Python в execution path.

## Architecture Intent

- весь execution loop живёт внутри `MT5/EA`;
- стратегии подключаются как pluggable `MQL5` classes;
- coordinator остаётся deterministic;
- persistent state и ratings хранятся через файловый слой `MT5`;
- никакого внешнего bridge/runtime в критическом торговом path.
