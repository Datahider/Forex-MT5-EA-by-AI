#ifndef FOREXMT5EA_STRATEGIES_DUMMYTRENDSTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_DUMMYTRENDSTRATEGY_MQH

#include "StrategyBase.mqh"

class DummyTrendStrategy : public StrategyBase
  {
public:
                     DummyTrendStrategy(void) : StrategyBase(STRATEGY_ID_DUMMY_TREND,"dummy_trend","Dummy Trend")
     {
     }

   virtual bool      Evaluate(const StrategyContext &context,StrategyDecision &decision)
     {
      m_evaluations++;
      ResetDecision(decision);

      decision.strategy_id=Id();
      decision.sequence=(long)context.bar_time;
      decision.produced_at=context.tick_time;

      if(context.spread_points>30)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2500;
         decision.reason="Spread too wide for dummy trend";
         return true;
        }

      if((((int)context.bar_time)/60)%2!=0)
        {
         decision.decision_type=DECISION_TYPE_BUY;
         decision.confidence_bps=6500;
         decision.reason="Odd-minute trend pulse";
         return true;
        }

      decision.decision_type=DECISION_TYPE_HOLD;
      decision.confidence_bps=4500;
      decision.reason="No trend pulse";
      return true;
     }
  };

#endif
