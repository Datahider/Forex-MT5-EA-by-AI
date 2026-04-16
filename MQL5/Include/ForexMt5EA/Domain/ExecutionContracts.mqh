#ifndef FOREXMT5EA_DOMAIN_EXECUTIONCONTRACTS_MQH
#define FOREXMT5EA_DOMAIN_EXECUTIONCONTRACTS_MQH

#include <ForexMt5EA/Domain/StrategyContracts.mqh>

enum ENUM_EXPOSURE_SIDE
  {
   EXPOSURE_SIDE_FLAT=0,
   EXPOSURE_SIDE_LONG=1,
   EXPOSURE_SIDE_SHORT=2
  };

enum ENUM_EXECUTION_ACTION
  {
   EXECUTION_ACTION_NONE=0,
   EXECUTION_ACTION_HOLD=1,
   EXECUTION_ACTION_OPEN_LONG=2,
   EXECUTION_ACTION_OPEN_SHORT=3,
   EXECUTION_ACTION_INCREASE_LONG=4,
   EXECUTION_ACTION_INCREASE_SHORT=5,
   EXECUTION_ACTION_REDUCE_LONG=6,
   EXECUTION_ACTION_REDUCE_SHORT=7,
   EXECUTION_ACTION_CLOSE_POSITION=8,
   EXECUTION_ACTION_FLIP_TO_LONG=9,
   EXECUTION_ACTION_FLIP_TO_SHORT=10,
   EXECUTION_ACTION_REJECT=11
  };

enum ENUM_RISK_STATUS_CODE
  {
   RISK_STATUS_UNKNOWN=0,
   RISK_STATUS_APPROVED=1,
   RISK_STATUS_BLOCKED_INVALID_CONTEXT=2,
   RISK_STATUS_BLOCKED_UNSUPPORTED_DECISION=3,
   RISK_STATUS_BLOCKED_WIDE_SPREAD=4,
   RISK_STATUS_BLOCKED_LOW_CONFIDENCE=5,
   RISK_STATUS_BLOCKED_INVALID_TARGET=6,
   RISK_STATUS_BLOCKED_IMPOSSIBLE_INTENT=7
  };

struct PositionSnapshot
  {
   string            symbol;
   ENUM_EXPOSURE_SIDE side;
   double            volume_lots;
   double            avg_price;
   bool              exists;
  };

struct ExecutionIntent
  {
   string            symbol;
   ENUM_DECISION_TYPE decision_type;
   ENUM_STRATEGY_ID  strategy_id;
   int               confidence_bps;
   long              sequence;
   ENUM_EXPOSURE_SIDE current_side;
   double            current_volume_lots;
   double            reference_price;
   string            rationale;
   datetime          produced_at;
  };

struct TargetExposure
  {
   string            symbol;
   ENUM_EXPOSURE_SIDE target_side;
   double            target_volume_lots;
   double            max_volume_lots;
   double            step_lots;
  };

struct RiskStatus
  {
   bool              allowed;
   ENUM_RISK_STATUS_CODE code;
   string            reason;
   string            policy_name;
   datetime          evaluated_at;
  };

struct ExecutionPlan
  {
   bool              dry_run;
   bool              executable;
   ENUM_EXECUTION_ACTION action;
   string            symbol;
   ENUM_EXPOSURE_SIDE current_side;
   ENUM_EXPOSURE_SIDE target_side;
   double            current_volume_lots;
   double            target_volume_lots;
   double            delta_lots;
   double            reference_price;
   string            summary;
   datetime          planned_at;
  };

string ExposureSideToString(const ENUM_EXPOSURE_SIDE side)
  {
   switch(side)
     {
      case EXPOSURE_SIDE_LONG:
         return "LONG";
      case EXPOSURE_SIDE_SHORT:
         return "SHORT";
      default:
         return "FLAT";
     }
  }

string ExecutionActionToString(const ENUM_EXECUTION_ACTION action)
  {
   switch(action)
     {
      case EXECUTION_ACTION_HOLD:
         return "HOLD";
      case EXECUTION_ACTION_OPEN_LONG:
         return "OPEN_LONG";
      case EXECUTION_ACTION_OPEN_SHORT:
         return "OPEN_SHORT";
      case EXECUTION_ACTION_INCREASE_LONG:
         return "INCREASE_LONG";
      case EXECUTION_ACTION_INCREASE_SHORT:
         return "INCREASE_SHORT";
      case EXECUTION_ACTION_REDUCE_LONG:
         return "REDUCE_LONG";
      case EXECUTION_ACTION_REDUCE_SHORT:
         return "REDUCE_SHORT";
      case EXECUTION_ACTION_CLOSE_POSITION:
         return "CLOSE_POSITION";
      case EXECUTION_ACTION_FLIP_TO_LONG:
         return "FLIP_TO_LONG";
      case EXECUTION_ACTION_FLIP_TO_SHORT:
         return "FLIP_TO_SHORT";
      case EXECUTION_ACTION_REJECT:
         return "REJECT";
      default:
         return "NONE";
     }
  }

string RiskStatusCodeToString(const ENUM_RISK_STATUS_CODE code)
  {
   switch(code)
     {
      case RISK_STATUS_APPROVED:
         return "APPROVED";
      case RISK_STATUS_BLOCKED_INVALID_CONTEXT:
         return "BLOCKED_INVALID_CONTEXT";
      case RISK_STATUS_BLOCKED_UNSUPPORTED_DECISION:
         return "BLOCKED_UNSUPPORTED_DECISION";
      case RISK_STATUS_BLOCKED_WIDE_SPREAD:
         return "BLOCKED_WIDE_SPREAD";
      case RISK_STATUS_BLOCKED_LOW_CONFIDENCE:
         return "BLOCKED_LOW_CONFIDENCE";
      case RISK_STATUS_BLOCKED_INVALID_TARGET:
         return "BLOCKED_INVALID_TARGET";
      case RISK_STATUS_BLOCKED_IMPOSSIBLE_INTENT:
         return "BLOCKED_IMPOSSIBLE_INTENT";
      default:
         return "UNKNOWN";
     }
  }

void ResetPositionSnapshot(PositionSnapshot &snapshot)
  {
   snapshot.symbol="";
   snapshot.side=EXPOSURE_SIDE_FLAT;
   snapshot.volume_lots=0.0;
   snapshot.avg_price=0.0;
   snapshot.exists=false;
  }

void ResetExecutionIntent(ExecutionIntent &intent)
  {
   intent.symbol="";
   intent.decision_type=DECISION_TYPE_NONE;
   intent.strategy_id=STRATEGY_ID_NONE;
   intent.confidence_bps=0;
   intent.sequence=0;
   intent.current_side=EXPOSURE_SIDE_FLAT;
   intent.current_volume_lots=0.0;
   intent.reference_price=0.0;
   intent.rationale="";
   intent.produced_at=0;
  }

void ResetTargetExposure(TargetExposure &target)
  {
   target.symbol="";
   target.target_side=EXPOSURE_SIDE_FLAT;
   target.target_volume_lots=0.0;
   target.max_volume_lots=0.0;
   target.step_lots=0.0;
  }

void ResetRiskStatus(RiskStatus &status)
  {
   status.allowed=false;
   status.code=RISK_STATUS_UNKNOWN;
   status.reason="";
   status.policy_name="";
   status.evaluated_at=0;
  }

void ResetExecutionPlan(ExecutionPlan &plan)
  {
   plan.dry_run=true;
   plan.executable=false;
   plan.action=EXECUTION_ACTION_NONE;
   plan.symbol="";
   plan.current_side=EXPOSURE_SIDE_FLAT;
   plan.target_side=EXPOSURE_SIDE_FLAT;
   plan.current_volume_lots=0.0;
   plan.target_volume_lots=0.0;
   plan.delta_lots=0.0;
   plan.reference_price=0.0;
   plan.summary="";
   plan.planned_at=0;
  }

#endif
