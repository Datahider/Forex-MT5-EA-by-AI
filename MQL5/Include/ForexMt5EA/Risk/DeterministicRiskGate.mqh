#ifndef FOREXMT5EA_RISK_DETERMINISTICRISKGATE_MQH
#define FOREXMT5EA_RISK_DETERMINISTICRISKGATE_MQH

#include <ForexMt5EA/Domain/ExecutionContracts.mqh>

class DeterministicRiskGate
  {
private:
   int               m_max_spread_points;
   int               m_min_confidence_bps;
   double            m_max_target_volume_lots;
   double            m_min_step_lots;

   double            NormalizeLots(const double lots,const double step) const
     {
      if(step<=0.0)
         return lots;

      return MathFloor((lots/step)+0.0000001)*step;
     }

public:
                     DeterministicRiskGate(void)
     {
      m_max_spread_points=30;
      m_min_confidence_bps=5500;
      m_max_target_volume_lots=0.10;
      m_min_step_lots=0.01;
     }

   void              Configure(const int max_spread_points,
                               const int min_confidence_bps,
                               const double max_target_volume_lots,
                               const double min_step_lots)
     {
      m_max_spread_points=max_spread_points;
      m_min_confidence_bps=min_confidence_bps;
      m_max_target_volume_lots=max_target_volume_lots;
      m_min_step_lots=min_step_lots;
     }

   bool              Evaluate(const StrategyContext &context,
                              const ExecutionIntent &intent,
                              TargetExposure &target,
                              RiskStatus &status) const
     {
      ResetRiskStatus(status);
      ResetTargetExposure(target);

      status.policy_name="deterministic-risk-gate-v1";
      status.evaluated_at=context.tick_time;
      target.symbol=intent.symbol;
      target.max_volume_lots=m_max_target_volume_lots;
      target.step_lots=m_min_step_lots;

      if(intent.symbol=="" || context.symbol=="" || intent.symbol!=context.symbol || intent.reference_price<=0.0)
        {
         status.code=RISK_STATUS_BLOCKED_INVALID_CONTEXT;
         status.reason="Invalid execution context";
         return false;
        }

      if(context.spread_points<0 || context.spread_points>m_max_spread_points)
        {
         status.code=RISK_STATUS_BLOCKED_WIDE_SPREAD;
         status.reason="Spread exceeds deterministic cap";
         return false;
        }

      if(intent.current_volume_lots<0.0 || m_max_target_volume_lots<=0.0 || m_min_step_lots<=0.0)
        {
         status.code=RISK_STATUS_BLOCKED_INVALID_TARGET;
         status.reason="Risk configuration produced invalid target";
         return false;
        }

      if(intent.decision_type==DECISION_TYPE_HOLD)
        {
         target.target_side=intent.current_side;
         target.target_volume_lots=NormalizeLots(intent.current_volume_lots,m_min_step_lots);
         status.allowed=true;
         status.code=RISK_STATUS_APPROVED;
         status.reason="Hold decision keeps current netting exposure";
         return true;
        }

      if(intent.confidence_bps<0 || intent.confidence_bps>10000 || intent.confidence_bps<m_min_confidence_bps)
        {
         status.code=RISK_STATUS_BLOCKED_LOW_CONFIDENCE;
         status.reason="Confidence below deterministic threshold";
         return false;
        }

      if(intent.decision_type==DECISION_TYPE_EXIT)
        {
         if(intent.current_side==EXPOSURE_SIDE_FLAT || intent.current_volume_lots<=0.0)
           {
            status.code=RISK_STATUS_BLOCKED_IMPOSSIBLE_INTENT;
            status.reason="Exit requested without open position";
            return false;
           }

         target.target_side=EXPOSURE_SIDE_FLAT;
         target.target_volume_lots=0.0;
         status.allowed=true;
         status.code=RISK_STATUS_APPROVED;
         status.reason="Exit approved";
         return true;
        }

      if(intent.decision_type==DECISION_TYPE_BUY)
        {
         if(intent.current_side==EXPOSURE_SIDE_SHORT && intent.current_volume_lots<=0.0)
           {
            status.code=RISK_STATUS_BLOCKED_IMPOSSIBLE_INTENT;
            status.reason="Short side without positive volume";
            return false;
           }

         target.target_side=EXPOSURE_SIDE_LONG;
         target.target_volume_lots=NormalizeLots(m_max_target_volume_lots,m_min_step_lots);
         if(target.target_volume_lots<=0.0)
           {
            status.code=RISK_STATUS_BLOCKED_INVALID_TARGET;
            status.reason="Target volume normalized to zero";
            return false;
           }

         status.allowed=true;
         status.code=RISK_STATUS_APPROVED;
         status.reason="Buy approved within deterministic cap";
         return true;
        }

      if(intent.decision_type==DECISION_TYPE_SELL)
        {
         if(intent.current_side==EXPOSURE_SIDE_LONG && intent.current_volume_lots<=0.0)
           {
            status.code=RISK_STATUS_BLOCKED_IMPOSSIBLE_INTENT;
            status.reason="Long side without positive volume";
            return false;
           }

         target.target_side=EXPOSURE_SIDE_SHORT;
         target.target_volume_lots=NormalizeLots(m_max_target_volume_lots,m_min_step_lots);
         if(target.target_volume_lots<=0.0)
           {
            status.code=RISK_STATUS_BLOCKED_INVALID_TARGET;
            status.reason="Target volume normalized to zero";
            return false;
           }

         status.allowed=true;
         status.code=RISK_STATUS_APPROVED;
         status.reason="Sell approved within deterministic cap";
         return true;
        }

      status.code=RISK_STATUS_BLOCKED_UNSUPPORTED_DECISION;
      status.reason="Unsupported decision for execution";
      return false;
     }
  };

#endif
