#ifndef FOREXMT5EA_STRATEGIES_STRATEGYBASE_MQH
#define FOREXMT5EA_STRATEGIES_STRATEGYBASE_MQH

#include <ForexMt5EA/Strategies/IStrategy.mqh>

class StrategyBase : public IStrategy
  {
protected:
   ENUM_STRATEGY_ID  m_id;
   string            m_key;
   string            m_name;
   int               m_evaluations;

public:
                     StrategyBase(const ENUM_STRATEGY_ID strategy_id,const string key,const string name)
     {
      m_id=strategy_id;
      m_key=key;
      m_name=name;
      m_evaluations=0;
     }

   virtual ENUM_STRATEGY_ID Id(void) const
     {
      return m_id;
     }

   virtual string    Key(void) const
     {
      return m_key;
     }

   virtual string    Name(void) const
     {
      return m_name;
     }

   virtual bool      LoadState(FileStateStore &store)
     {
      string payload;
      if(!store.LoadStrategyState(m_key,payload))
         return false;

      m_evaluations=(int)StringToInteger(payload);
      return true;
     }

   virtual bool      SaveState(FileStateStore &store)
     {
      return store.SaveStrategyState(m_key,IntegerToString(m_evaluations));
     }
  };

#endif
