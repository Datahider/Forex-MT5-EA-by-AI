#property strict
#property description "MQL5-native EA skeleton with deterministic coordinator and pluggable strategies"
#property version   "0.1"

#include <ForexMt5EA/Coordination/DeterministicCoordinator.mqh>
#include <ForexMt5EA/Strategies/DummyTrendStrategy.mqh>
#include <ForexMt5EA/Strategies/DummyMeanReversionStrategy.mqh>

input bool InpPersistState=true;

FileStateStore                g_store("ForexMt5EA");
DeterministicCoordinator      g_coordinator;
DummyTrendStrategy            g_trend_strategy;
DummyMeanReversionStrategy    g_mean_reversion_strategy;

bool BuildStrategyContext(StrategyContext &context)
  {
   context.symbol=_Symbol;
   context.timeframe=_Period;
   context.tick_time=TimeCurrent();
   context.bar_time=iTime(_Symbol,_Period,0);
   context.bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   context.ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   context.last=SymbolInfoDouble(_Symbol,SYMBOL_LAST);
   context.spread_points=(int)MathRound((context.ask-context.bid)/_Point);

   if(context.last<=0.0)
      context.last=(context.bid+context.ask)/2.0;

   return context.bar_time>0;
  }

int OnInit(void)
  {
   IStrategy *strategies[2];
   strategies[0]=&g_trend_strategy;
   strategies[1]=&g_mean_reversion_strategy;

   g_coordinator.AttachStore(g_store);
   g_coordinator.Configure(strategies,ArraySize(strategies));
   g_coordinator.Initialize();

   Print("ForexMt5EA skeleton initialized");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(InpPersistState)
      g_coordinator.Persist();

   PrintFormat("ForexMt5EA skeleton deinitialized, reason=%d",reason);
  }

void OnTick(void)
  {
   StrategyContext context;
   if(!BuildStrategyContext(context))
      return;

   StrategyDecision decision;
   if(!g_coordinator.Evaluate(context,decision))
      return;

   if(InpPersistState)
      g_coordinator.Persist();

   PrintFormat("Coordinator decision: strategy=%s decision=%s confidence=%d reason=%s",
               StrategyIdToString(decision.strategy_id),
               DecisionTypeToString(decision.decision_type),
               decision.confidence_bps,
               decision.reason);

   // Order execution is intentionally omitted in this skeleton.
  }
