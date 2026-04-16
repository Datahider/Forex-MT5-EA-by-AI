#ifndef FOREXMT5EA_STRATEGIES_DUMMYMEANREVERSIONSTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_DUMMYMEANREVERSIONSTRATEGY_MQH

#include "StrategyBase.mqh"

class DummyMeanReversionStrategy : public StrategyBase
  {
public:
                     DummyMeanReversionStrategy(void) : StrategyBase(STRATEGY_ID_DUMMY_MEAN_REVERSION,"dummy_mean_reversion","Dummy Mean Reversion")
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
         decision.confidence_bps=2000;
         decision.reason="Spread too wide for dummy mean reversion";
         return true;
        }

      if((((int)context.bar_time)/60)%2==0)
        {
         decision.decision_type=DECISION_TYPE_SELL;
         decision.confidence_bps=6200;
         decision.reason="Even-minute reversion pulse";
         return true;
        }

      decision.decision_type=DECISION_TYPE_HOLD;
      decision.confidence_bps=4300;
      decision.reason="No reversion pulse";
      return true;
     }
  };

#endif
