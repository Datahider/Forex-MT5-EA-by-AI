#ifndef FOREXMT5EA_STRATEGIES_ISTRATEGY_MQH
#define FOREXMT5EA_STRATEGIES_ISTRATEGY_MQH

#include "../Domain/StrategyContracts.mqh"
#include "../Storage/FileStateStore.mqh"

class IStrategy
  {
public:
   virtual ENUM_STRATEGY_ID Id(void) const=0;
   virtual string          Key(void) const=0;
   virtual string          Name(void) const=0;
   virtual bool            Evaluate(const StrategyContext &context,StrategyDecision &decision)=0;
   virtual bool            LoadState(FileStateStore &store)=0;
   virtual bool            SaveState(FileStateStore &store)=0;
  };

#endif
