#ifndef FOREXMT5EA_STRATEGIES_RSIMEANREVERSIONSTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_RSIMEANREVERSIONSTRATEGY_MQH

#include "StrategyBase.mqh"

class RsiMeanReversionStrategy : public StrategyBase
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_rsi_handle;
   int               m_bands_handle;
   datetime          m_last_bar_time;

   void              ReleaseHandles(void)
     {
      if(m_rsi_handle!=INVALID_HANDLE)
         IndicatorRelease(m_rsi_handle);
      if(m_bands_handle!=INVALID_HANDLE)
         IndicatorRelease(m_bands_handle);

      m_rsi_handle=INVALID_HANDLE;
      m_bands_handle=INVALID_HANDLE;
     }

   bool              EnsureHandles(const StrategyContext &context)
     {
      if(m_symbol==context.symbol
         && m_timeframe==context.timeframe
         && m_rsi_handle!=INVALID_HANDLE
         && m_bands_handle!=INVALID_HANDLE)
         return true;

      ReleaseHandles();

      m_symbol=context.symbol;
      m_timeframe=context.timeframe;
      m_rsi_handle=iRSI(m_symbol,m_timeframe,14,PRICE_CLOSE);
      m_bands_handle=iBands(m_symbol,m_timeframe,20,0,2.0,PRICE_CLOSE);

      return m_rsi_handle!=INVALID_HANDLE && m_bands_handle!=INVALID_HANDLE;
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
                     RsiMeanReversionStrategy(void) : StrategyBase(STRATEGY_ID_RSI_MEAN_REVERSION,"rsi_mean_reversion","RSI Mean Reversion")
     {
      m_symbol="";
      m_timeframe=PERIOD_CURRENT;
      m_rsi_handle=INVALID_HANDLE;
      m_bands_handle=INVALID_HANDLE;
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
         decision.confidence_bps=2200;
         decision.reason="Spread too wide for RSI reversion";
         return true;
        }

      if(!EnsureHandles(context))
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2000;
         decision.reason="RSI/Bands handles unavailable";
         return true;
        }

      if(context.bar_time==m_last_bar_time)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=3100;
         decision.reason="RSI reversion waits for a new closed bar";
         return true;
        }

      m_last_bar_time=context.bar_time;

      double rsi_values[2];
      double upper_values[2];
      double lower_values[2];
      double close_values[2];
      if(CopyBuffer(m_rsi_handle,0,1,2,rsi_values)!=2
         || CopyBuffer(m_bands_handle,1,1,2,upper_values)!=2
         || CopyBuffer(m_bands_handle,2,1,2,lower_values)!=2
         || CopyClose(context.symbol,context.timeframe,1,2,close_values)!=2)
        {
         decision.decision_type=DECISION_TYPE_HOLD;
         decision.confidence_bps=2200;
         decision.reason="RSI reversion buffers unavailable";
         return true;
        }

      const bool bullish_recovery=(close_values[0]<lower_values[0]
                                   && rsi_values[0]<30.0
                                   && close_values[1]>lower_values[1]
                                   && rsi_values[1]>35.0);
      const bool bearish_recovery=(close_values[0]>upper_values[0]
                                   && rsi_values[0]>70.0
                                   && close_values[1]<upper_values[1]
                                   && rsi_values[1]<65.0);

      if(bullish_recovery)
        {
         decision.decision_type=DECISION_TYPE_BUY;
         decision.confidence_bps=6900;
         decision.reason="Price re-entered Bollinger band after oversold RSI washout";
         return true;
        }

      if(bearish_recovery)
        {
         decision.decision_type=DECISION_TYPE_SELL;
         decision.confidence_bps=6900;
         decision.reason="Price re-entered Bollinger band after overbought RSI washout";
         return true;
        }

      decision.decision_type=DECISION_TYPE_HOLD;
      decision.confidence_bps=4100;
      decision.reason="No Bollinger/RSI mean reversion setup";
      return true;
     }
  };

#endif
