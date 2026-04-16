#property strict
#property description "MQL5-native EA with deterministic coordinator, risk gate, netting planner and guarded OrderSend execution"
#property version   "1.3"

#include "Include/Coordination/DeterministicCoordinator.mqh"
#include "Include/Execution/NettingExecutionPlanner.mqh"
#include "Include/Execution/Mt5TradeExecutor.mqh"
#include "Include/Risk/DeterministicRiskGate.mqh"
#include "Include/Strategies/DummyTrendStrategy.mqh"
#include "Include/Strategies/DummyMeanReversionStrategy.mqh"

input bool InpPersistState=true;
input bool InpEnableLiveExecution=false;
input int InpMaxSpreadPoints=30;
input int InpMinConfidenceBps=5500;
input double InpMaxTargetVolumeLots=0.10;
input double InpLotStep=0.01;
input uint InpExecutionDeviationPoints=20;
input long InpExpertMagicNumber=20260416;

FileStateStore                g_store("ForexMt5EA");
DeterministicCoordinator      g_coordinator;
DeterministicRiskGate         g_risk_gate;
NettingExecutionPlanner       g_execution_planner;
Mt5TradeExecutor              g_trade_executor;
DummyTrendStrategy            g_trend_strategy;
DummyMeanReversionStrategy    g_mean_reversion_strategy;

bool IsTesterExecutionRuntime(void)
  {
   return (bool)MQLInfoInteger(MQL_TESTER);
  }

bool IsRuntimeExecutionAllowed(void)
  {
   if(IsTesterExecutionRuntime())
      return true;

   if(!InpEnableLiveExecution)
      return false;

   return (bool)MQLInfoInteger(MQL_TRADE_ALLOWED) && (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
  }

string ExecutionRuntimeModeLabel(void)
  {
   if(IsTesterExecutionRuntime())
      return "TESTER_ORDER_SEND_ENABLED";

   if(InpEnableLiveExecution && IsRuntimeExecutionAllowed())
      return "LIVE_ORDER_SEND_ENABLED";

   if(InpEnableLiveExecution)
      return "LIVE_ORDER_SEND_BLOCKED";

   return "LIVE_ORDER_SEND_DISABLED";
  }

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
   snapshot.ticket=(ulong)PositionGetInteger(POSITION_TICKET);

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
   g_trade_executor.Configure(InpExpertMagicNumber,InpExecutionDeviationPoints);

   PrintFormat("ForexMt5EA initialized, runtime_mode=%s",ExecutionRuntimeModeLabel());
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

   ExecutionReport execution_report;
   g_trade_executor.Execute(plan,position,IsRuntimeExecutionAllowed(),execution_report);

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

   PrintFormat("Execution plan: executable=%s action=%s current=%s %.2f -> target=%s %.2f delta=%.2f price=%.5f summary=%s",
               (plan.executable ? "true" : "false"),
               ExecutionActionToString(plan.action),
               ExposureSideToString(plan.current_side),
               plan.current_volume_lots,
               ExposureSideToString(plan.target_side),
               plan.target_volume_lots,
               plan.delta_lots,
               plan.reference_price,
               plan.summary);

   PrintFormat("Execution runtime: mode=%s status=%s attempted=%s request_built=%s request_sent=%s accepted=%s action=%s order_type=%s request_volume=%.2f request_price=%.5f position_ticket=%I64u retcode=%u deal=%I64u order=%I64u message=%s",
               ExecutionRuntimeModeLabel(),
               ExecutionRuntimeStatusToString(execution_report.runtime_status),
               (execution_report.attempted ? "true" : "false"),
               (execution_report.request_built ? "true" : "false"),
               (execution_report.request_sent ? "true" : "false"),
               (execution_report.result_accepted ? "true" : "false"),
               ExecutionActionToString(execution_report.action),
               OrderTypeToString(execution_report.order_type),
               execution_report.request_volume_lots,
               execution_report.request_price,
               execution_report.request_position_ticket,
               execution_report.result_retcode,
               execution_report.result_deal,
               execution_report.result_order,
               execution_report.message);
  }
