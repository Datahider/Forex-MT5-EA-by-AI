#ifndef FOREXMT5EA_STRATEGIES_RANGEBREAKOUTSTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_RANGEBREAKOUTSTRATEGY_MQH

#include "StrategyBase.mqh"

class RangeBreakoutStrategy : public StrategyBase
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_atr_handle;
   datetime          m_last_bar_time;

   void              ReleaseHandles(void)
     {
      if(m_atr_handle!=INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);

      m_atr_handle=INVALID_HANDLE;
     }

   bool              EnsureHandles(const StrategyContext &context)
     {
      if(m_symbol==context.symbol
         && m_timeframe==context.timeframe
         && m_atr_handle!=INVALID_HANDLE)
         return true;

      ReleaseHandles();

      m_symbol=context.symbol;
      m_timeframe=context.timeframe;
      m_atr_handle=iATR(m_symbol,m_timeframe,14);

      return m_atr_handle!=INVALID_HANDLE;
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
                     RangeBreakoutStrategy(void) : StrategyBase(STRATEGY_ID_RANGE_BREAKOUT,"range_breakout","Range Breakout")
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_atr_handle=INVALID_HANDLE;
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
         decision.confidence_bps=2300;
         decision.reason="Spread too wide for breakout";
         return true;
        }

      if(!EnsureHandles(context))
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2000;
         decision.reason="ATR handle unavailable";
         return true;
        }

      if(context.bar_time==m_last_bar_time)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=3000;
         decision.reason="Breakout strategy waits for a new closed bar";
         return true;
        }

      m_last_bar_time=context.bar_time;

      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      if(CopyRates(context.symbol,context.timeframe,0,24,rates)<23)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2200;
         decision.reason="Breakout price history unavailable";
         return true;
        }

      double atr_values[1];
      if(CopyBuffer(m_atr_handle,0,1,1,atr_values)!=1 || atr_values[0]<=0.0)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2200;
         decision.reason="ATR buffer unavailable";
         return true;
        }

      double highest_high=rates[2].high;
      double lowest_low=rates[2].low;
      for(int i=3;i<=21;i++)
        {
         highest_high=MathMax(highest_high,rates[i].high);
         lowest_low=MathMin(lowest_low,rates[i].low);
        }

      const double candle_range=MathMax(rates[1].high-rates[1].low,_Point);
      const double bullish_extension=rates[1].close-highest_high;
      const double bearish_extension=lowest_low-rates[1].close;
      const bool bullish_close_near_high=((rates[1].high-rates[1].close)/candle_range)<=0.35;
      const bool bearish_close_near_low=((rates[1].close-rates[1].low)/candle_range)<=0.35;
      const bool bullish_breakout=(rates[1].close>highest_high
                                   && rates[1].close>rates[1].open
                                   && bullish_close_near_high
                                   && bullish_extension>=0.15*atr_values[0]);
      const bool bearish_breakout=(rates[1].close<lowest_low
                                   && rates[1].close<rates[1].open
                                   && bearish_close_near_low
                                   && bearish_extension>=0.15*atr_values[0]);

      if(bullish_breakout)
        {
         decision.decision_type=DECISION_TYPE_BUY;
         decision.confidence_bps=7600;
         decision.reason="Closed above 20-bar range high with ATR-backed breakout candle";
         return true;
        }

      if(bearish_breakout)
        {
         decision.decision_type=DECISION_TYPE_SELL;
         decision.confidence_bps=7600;
         decision.reason="Closed below 20-bar range low with ATR-backed breakout candle";
         return true;
        }

      decision.decision_type=DECISION_TYPE_HOLD;
      decision.confidence_bps=4300;
      decision.reason="No confirmed 20-bar breakout";
      return true;
     }
  };

#endif
