#ifndef FOREXMT5EA_DOMAIN_STRATEGYCONTRACTS_MQH
#define FOREXMT5EA_DOMAIN_STRATEGYCONTRACTS_MQH

enum ENUM_STRATEGY_ID
  {
   STRATEGY_ID_NONE=0,
   STRATEGY_ID_EMA_TREND=1,
   STRATEGY_ID_RSI_MEAN_REVERSION=2,
   STRATEGY_ID_RANGE_BREAKOUT=3
  };

enum ENUM_DECISION_TYPE
  {
   DECISION_TYPE_NONE=0,
   DECISION_TYPE_HOLD=1,
   DECISION_TYPE_BUY=2,
   DECISION_TYPE_SELL=3,
   DECISION_TYPE_EXIT=4
  };

struct StrategyContext
  {
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   datetime          tick_time;
   datetime          bar_time;
   double            bid;
   double            ask;
   double            last;
   int               spread_points;
  };

struct StrategyDecision
  {
   ENUM_STRATEGY_ID  strategy_id;
   ENUM_DECISION_TYPE decision_type;
   int               confidence_bps;
   long              sequence;
   string            reason;
   datetime          produced_at;
  };

struct StrategyRating
  {
   ENUM_STRATEGY_ID  strategy_id;
   int               score_bps;
   int               weight_bps;
   datetime          updated_at;
  };

string StrategyIdToString(const ENUM_STRATEGY_ID strategy_id)
  {
   switch(strategy_id)
     {
      case STRATEGY_ID_EMA_TREND:
         return "EMA_TREND";
      case STRATEGY_ID_RSI_MEAN_REVERSION:
         return "RSI_MEAN_REVERSION";
      case STRATEGY_ID_RANGE_BREAKOUT:
         return "RANGE_BREAKOUT";
      default:
         return "NONE";
     }
  }

string DecisionTypeToString(const ENUM_DECISION_TYPE decision_type)
  {
   switch(decision_type)
     {
      case DECISION_TYPE_HOLD:
         return "HOLD";
      case DECISION_TYPE_BUY:
         return "BUY";
      case DECISION_TYPE_SELL:
         return "SELL";
      case DECISION_TYPE_EXIT:
         return "EXIT";
      default:
         return "NONE";
     }
  }

void ResetDecision(StrategyDecision &decision)
  {
   decision.strategy_id=STRATEGY_ID_NONE;
   decision.decision_type=DECISION_TYPE_NONE;
   decision.confidence_bps=0;
   decision.sequence=0;
   decision.reason="";
   decision.produced_at=0;
  }

void ResetRating(StrategyRating &rating,const ENUM_STRATEGY_ID strategy_id)
  {
   rating.strategy_id=strategy_id;
   rating.score_bps=5000;
   rating.weight_bps=10000;
   rating.updated_at=TimeCurrent();
  }

#endif
