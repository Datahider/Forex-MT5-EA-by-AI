#ifndef FOREXMT5EA_COORDINATION_DETERMINISTICCOORDINATOR_MQH
#define FOREXMT5EA_COORDINATION_DETERMINISTICCOORDINATOR_MQH

#include "../Strategies/IStrategy.mqh"

class DeterministicCoordinator
  {
private:
   IStrategy         *m_strategies[];
   StrategyRating    m_ratings[];
   FileStateStore    *m_store;

   int               FindRatingIndex(const ENUM_STRATEGY_ID strategy_id) const
     {
      const int count=ArraySize(m_ratings);
      for(int i=0;i<count;i++)
         if(m_ratings[i].strategy_id==strategy_id)
            return i;

      return -1;
     }

   StrategyRating    EnsureRating(const ENUM_STRATEGY_ID strategy_id)
     {
      const int rating_index=FindRatingIndex(strategy_id);
      if(rating_index>=0)
         return m_ratings[rating_index];

      StrategyRating rating;
      ResetRating(rating,strategy_id);

      const int next_index=ArraySize(m_ratings);
      ArrayResize(m_ratings,next_index+1);
      m_ratings[next_index]=rating;

      return rating;
     }

public:
                     DeterministicCoordinator(void)
     {
      m_store=NULL;
      ArrayResize(m_strategies,0);
      ArrayResize(m_ratings,0);
     }

   void              AttachStore(FileStateStore &store)
     {
      m_store=&store;
     }

   void              Configure(IStrategy *strategies[],const int count)
     {
      ArrayResize(m_strategies,count);
      for(int i=0;i<count;i++)
         m_strategies[i]=strategies[i];
     }

   bool              Initialize(void)
     {
      if(m_store!=NULL)
         m_store.LoadRatings(m_ratings);

      const int count=ArraySize(m_strategies);
      for(int i=0;i<count;i++)
        {
         if(m_strategies[i]==NULL)
            continue;

         EnsureRating(m_strategies[i].Id());

         if(m_store!=NULL)
            m_strategies[i].LoadState(*m_store);
        }

      return true;
     }

   bool              Persist(void)
     {
      bool ok=true;

      if(m_store!=NULL)
         ok=m_store.SaveRatings(m_ratings);

      const int count=ArraySize(m_strategies);
      for(int i=0;i<count;i++)
        {
         if(m_strategies[i]==NULL || m_store==NULL)
            continue;

         ok=m_strategies[i].SaveState(*m_store) && ok;
        }

      return ok;
     }

   bool              Evaluate(const StrategyContext &context,StrategyDecision &winning_decision)
     {
      ResetDecision(winning_decision);
      winning_decision.decision_type=DECISION_TYPE_HOLD;
      winning_decision.reason="No strategy proposals";
      winning_decision.produced_at=context.tick_time;

      long best_score=-1;
      const int count=ArraySize(m_strategies);

      for(int i=0;i<count;i++)
        {
         if(m_strategies[i]==NULL)
            continue;

         StrategyDecision candidate;
         ResetDecision(candidate);

         if(!m_strategies[i].Evaluate(context,candidate))
            continue;

         const StrategyRating rating=EnsureRating(candidate.strategy_id);
         const long arbitration_score=(long)rating.weight_bps*(long)candidate.confidence_bps;

         if(arbitration_score>best_score)
           {
            best_score=arbitration_score;
            winning_decision=candidate;
            continue;
           }

         if(arbitration_score==best_score)
           {
            if(candidate.confidence_bps>winning_decision.confidence_bps)
              {
               winning_decision=candidate;
               continue;
              }

            if(candidate.confidence_bps==winning_decision.confidence_bps && (int)candidate.strategy_id<(int)winning_decision.strategy_id)
               winning_decision=candidate;
           }
        }

      return true;
     }
  };

#endif
