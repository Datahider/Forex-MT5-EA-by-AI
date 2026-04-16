#ifndef FOREXMT5EA_EXECUTION_DRYRUNEXECUTIONPLANNER_MQH
#define FOREXMT5EA_EXECUTION_DRYRUNEXECUTIONPLANNER_MQH

#include "../Domain/ExecutionContracts.mqh"

class DryRunExecutionPlanner
  {
private:
   double            SignedVolume(const ENUM_EXPOSURE_SIDE side,const double volume_lots) const
     {
      if(side==EXPOSURE_SIDE_LONG)
         return volume_lots;

      if(side==EXPOSURE_SIDE_SHORT)
         return -volume_lots;

      return 0.0;
     }

public:
   bool              BuildPlan(const ExecutionIntent &intent,
                               const TargetExposure &target,
                               const RiskStatus &status,
                               ExecutionPlan &plan) const
     {
      ResetExecutionPlan(plan);

      plan.symbol=intent.symbol;
      plan.current_side=intent.current_side;
      plan.target_side=target.target_side;
      plan.current_volume_lots=intent.current_volume_lots;
      plan.target_volume_lots=target.target_volume_lots;
      plan.reference_price=intent.reference_price;
      plan.planned_at=intent.produced_at;

      if(!status.allowed)
        {
         plan.action=EXECUTION_ACTION_REJECT;
         plan.summary="Dry-run rejected by risk gate: "+status.reason;
         return true;
        }

      const double current_signed=SignedVolume(intent.current_side,intent.current_volume_lots);
      const double target_signed=SignedVolume(target.target_side,target.target_volume_lots);
      plan.delta_lots=MathAbs(target_signed-current_signed);

      if(target.target_side==intent.current_side && MathAbs(target.target_volume_lots-intent.current_volume_lots)<0.0000001)
        {
         plan.action=EXECUTION_ACTION_HOLD;
         plan.executable=true;
         plan.summary="Dry-run hold: target exposure already satisfied";
         return true;
        }

      if(target.target_side==EXPOSURE_SIDE_FLAT)
        {
         plan.action=EXECUTION_ACTION_CLOSE_POSITION;
         plan.executable=intent.current_side!=EXPOSURE_SIDE_FLAT && intent.current_volume_lots>0.0;
         plan.summary="Dry-run close to flat netting exposure";
         return true;
        }

      if(intent.current_side==EXPOSURE_SIDE_FLAT)
        {
         plan.action=(target.target_side==EXPOSURE_SIDE_LONG ? EXECUTION_ACTION_OPEN_LONG : EXECUTION_ACTION_OPEN_SHORT);
         plan.executable=target.target_volume_lots>0.0;
         plan.summary="Dry-run open from flat netting exposure";
         return true;
        }

      if(intent.current_side!=target.target_side)
        {
         plan.action=(target.target_side==EXPOSURE_SIDE_LONG ? EXECUTION_ACTION_FLIP_TO_LONG : EXECUTION_ACTION_FLIP_TO_SHORT);
         plan.executable=target.target_volume_lots>0.0;
         plan.summary="Dry-run flip netting exposure through opposite-side deal";
         return true;
        }

      if(target.target_volume_lots>intent.current_volume_lots)
        {
         plan.action=(target.target_side==EXPOSURE_SIDE_LONG ? EXECUTION_ACTION_INCREASE_LONG : EXECUTION_ACTION_INCREASE_SHORT);
         plan.executable=true;
         plan.summary="Dry-run increase existing netting exposure";
         return true;
        }

      plan.action=(target.target_side==EXPOSURE_SIDE_LONG ? EXECUTION_ACTION_REDUCE_LONG : EXECUTION_ACTION_REDUCE_SHORT);
      plan.executable=target.target_volume_lots>=0.0;
      plan.summary="Dry-run reduce existing netting exposure";
      return true;
     }
  };

#endif
