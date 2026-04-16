#property strict
#property description "MQL5-native EA skeleton with deterministic coordinator, risk gate and dry-run execution planner"
#property version   "0.2"

#include <ForexMt5EA/Coordination/DeterministicCoordinator.mqh>
#include <ForexMt5EA/Execution/DryRunExecutionPlanner.mqh>
#include <ForexMt5EA/Risk/DeterministicRiskGate.mqh>
#include <ForexMt5EA/Strategies/DummyTrendStrategy.mqh>
#include <ForexMt5EA/Strategies/DummyMeanReversionStrategy.mqh>

input bool InpPersistState=true;
input int InpMaxSpreadPoints=30;
input int InpMinConfidenceBps=5500;
input double InpMaxTargetVolumeLots=0.10;
input double InpLotStep=0.01;

FileStateStore                g_store("ForexMt5EA");
DeterministicCoordinator      g_coordinator;
DeterministicRiskGate         g_risk_gate;
DryRunExecutionPlanner        g_execution_planner;
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

bool BuildPositionSnapshot(PositionSnapshot &snapshot)
  {
   ResetPositionSnapshot(snapshot);
   snapshot.symbol=_Symbol;

   if(!PositionSelect(_Symbol))
      return true;

   snapshot.exists=true;
   snapshot.volume_lots=PositionGetDouble(POSITION_VOLUME);
   snapshot.avg_price=PositionGetDouble(POSITION_PRICE_OPEN);

   const long position_type=PositionGetInteger(POSITION_TYPE);
   if(position_type==POSITION_TYPE_BUY)
      snapshot.side=EXPOSURE_SIDE_LONG;
   else if(position_type==POSITION_TYPE_SELL)
      snapshot.side=EXPOSURE_SIDE_SHORT;
   else
      snapshot.side=EXPOSURE_SIDE_FLAT;

   return true;
  }

bool BuildExecutionIntent(const StrategyContext &context,
                          const StrategyDecision &decision,
                          const PositionSnapshot &position,
                          ExecutionIntent &intent)
  {
   ResetExecutionIntent(intent);

   intent.symbol=context.symbol;
   intent.decision_type=decision.decision_type;
   intent.strategy_id=decision.strategy_id;
   intent.confidence_bps=decision.confidence_bps;
   intent.sequence=decision.sequence;
   intent.current_side=position.side;
   intent.current_volume_lots=position.volume_lots;
   intent.reference_price=(decision.decision_type==DECISION_TYPE_SELL ? context.bid : context.ask);
   intent.rationale=decision.reason;
   intent.produced_at=decision.produced_at;

   if(decision.decision_type==DECISION_TYPE_HOLD)
      intent.reference_price=context.last;

   if(decision.decision_type==DECISION_TYPE_EXIT)
      intent.reference_price=(position.side==EXPOSURE_SIDE_SHORT ? context.ask : context.bid);

   return true;
  }

int OnInit(void)
  {
   IStrategy *strategies[2];
   strategies[0]=&g_trend_strategy;
   strategies[1]=&g_mean_reversion_strategy;

   g_coordinator.AttachStore(g_store);
   g_coordinator.Configure(strategies,ArraySize(strategies));
   g_coordinator.Initialize();
   g_risk_gate.Configure(InpMaxSpreadPoints,InpMinConfidenceBps,InpMaxTargetVolumeLots,InpLotStep);

   Print("ForexMt5EA skeleton initialized in dry-run mode");
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

   PositionSnapshot position;
   if(!BuildPositionSnapshot(position))
      return;

   ExecutionIntent intent;
   BuildExecutionIntent(context,decision,position,intent);

   TargetExposure target;
   RiskStatus risk_status;
   g_risk_gate.Evaluate(context,intent,target,risk_status);

   ExecutionPlan plan;
   g_execution_planner.BuildPlan(intent,target,risk_status,plan);

   if(InpPersistState)
      g_coordinator.Persist();

   PrintFormat("Coordinator decision: strategy=%s decision=%s confidence=%d reason=%s",
               StrategyIdToString(decision.strategy_id),
               DecisionTypeToString(decision.decision_type),
               decision.confidence_bps,
               decision.reason);

   PrintFormat("Risk status: allowed=%s code=%s reason=%s target_side=%s target_volume=%.2f",
               (risk_status.allowed ? "true" : "false"),
               RiskStatusCodeToString(risk_status.code),
               risk_status.reason,
               ExposureSideToString(target.target_side),
               target.target_volume_lots);

   PrintFormat("Execution plan: dry_run=%s executable=%s action=%s current=%s %.2f -> target=%s %.2f delta=%.2f price=%.5f summary=%s",
               (plan.dry_run ? "true" : "false"),
               (plan.executable ? "true" : "false"),
               ExecutionActionToString(plan.action),
               ExposureSideToString(plan.current_side),
               plan.current_volume_lots,
               ExposureSideToString(plan.target_side),
               plan.target_volume_lots,
               plan.delta_lots,
               plan.reference_price,
               plan.summary);

   // Real order placement remains intentionally disabled in this skeleton.
  }
