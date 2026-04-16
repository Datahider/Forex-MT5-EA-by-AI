#ifndef FOREXMT5EA_STRATEGIES_EMATRENDSTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_EMATRENDSTRATEGY_MQH

#include "StrategyBase.mqh"

class EmaTrendStrategy : public StrategyBase
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_fast_ema_handle;
   int               m_slow_ema_handle;
   int               m_adx_handle;
   datetime          m_last_bar_time;

   void              ReleaseHandles(void)
     {
      if(m_fast_ema_handle!=INVALID_HANDLE)
         IndicatorRelease(m_fast_ema_handle);
      if(m_slow_ema_handle!=INVALID_HANDLE)
         IndicatorRelease(m_slow_ema_handle);
      if(m_adx_handle!=INVALID_HANDLE)
         IndicatorRelease(m_adx_handle);

      m_fast_ema_handle=INVALID_HANDLE;
      m_slow_ema_handle=INVALID_HANDLE;
      m_adx_handle=INVALID_HANDLE;
     }

   bool              EnsureHandles(const StrategyContext &context)
     {
      if(m_symbol==context.symbol
         && m_timeframe==context.timeframe
         && m_fast_ema_handle!=INVALID_HANDLE
         && m_slow_ema_handle!=INVALID_HANDLE
         && m_adx_handle!=INVALID_HANDLE)
         return true;

      ReleaseHandles();

      m_symbol=context.symbol;
      m_timeframe=context.timeframe;
      m_fast_ema_handle=iMA(m_symbol,m_timeframe,21,0,MODE_EMA,PRICE_CLOSE);
      m_slow_ema_handle=iMA(m_symbol,m_timeframe,55,0,MODE_EMA,PRICE_CLOSE);
      m_adx_handle=iADX(m_symbol,m_timeframe,14);

      return m_fast_ema_handle!=INVALID_HANDLE
             && m_slow_ema_handle!=INVALID_HANDLE
             && m_adx_handle!=INVALID_HANDLE;
     }

protected:
   virtual string    SerializeState(void) const
     {
      return StringFormat("%d|%I64d",m_evaluations,(long)m_last_bar_time);
     }

   virtual bool      DeserializeState(const string payload)
     {
      string parts[];
      const int count=StringSplit(payload,'|',parts);
      if(count>=1)
         m_evaluations=(int)StringToInteger(parts[0]);
      if(count>=2)
         m_last_bar_time=(datetime)StringToInteger(parts[1]);
      return true;
     }

public:
                     EmaTrendStrategy(void) : StrategyBase(STRATEGY_ID_EMA_TREND,"ema_trend","EMA Trend")
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_fast_ema_handle=INVALID_HANDLE;
      m_slow_ema_handle=INVALID_HANDLE;
      m_adx_handle=INVALID_HANDLE;
      m_last_bar_time=0;
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
         decision.reason="Spread too wide for EMA trend";
         return true;
        }

      if(!EnsureHandles(context))
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2000;
         decision.reason="EMA/ADX handles unavailable";
         return true;
        }

      if(context.bar_time==m_last_bar_time)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=3200;
         decision.reason="EMA trend waits for a new closed bar";
         return true;
        }

      m_last_bar_time=context.bar_time;

      double fast_values[2];
      double slow_values[2];
      double adx_values[1];
      if(CopyBuffer(m_fast_ema_handle,0,1,2,fast_values)!=2
         || CopyBuffer(m_slow_ema_handle,0,1,2,slow_values)!=2
         || CopyBuffer(m_adx_handle,0,1,1,adx_values)!=1)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2200;
         decision.reason="EMA trend buffers unavailable";
         return true;
        }

      const bool bullish_cross=(fast_values[0]<=slow_values[0] && fast_values[1]>slow_values[1]);
      const bool bearish_cross=(fast_values[0]>=slow_values[0] && fast_values[1]<slow_values[1]);
      const bool trend_strength_ok=(adx_values[0]>=22.0);

      if(bullish_cross && trend_strength_ok)
        {
         decision.decision_type=DECISION_TYPE_BUY;
         decision.confidence_bps=7300;
         decision.reason="Fast EMA crossed above slow EMA with ADX confirmation";
         return true;
        }

      if(bearish_cross && trend_strength_ok)
        {
         decision.decision_type=DECISION_TYPE_SELL;
         decision.confidence_bps=7300;
         decision.reason="Fast EMA crossed below slow EMA with ADX confirmation";
         return true;
        }

      decision.decision_type=DECISION_TYPE_HOLD;
      decision.confidence_bps=4200;
      decision.reason="No confirmed EMA trend crossover";
      return true;
     }
  };

#endif
