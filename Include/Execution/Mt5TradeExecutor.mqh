#ifndef FOREXMT5EA_EXECUTION_MT5TRADEEXECUTOR_MQH
#define FOREXMT5EA_EXECUTION_MT5TRADEEXECUTOR_MQH

#include "../Domain/ExecutionContracts.mqh"

class Mt5TradeExecutor
  {
private:
   long              m_magic_number;
   uint              m_deviation_points;

   bool              ResolveFillMode(const string symbol,ENUM_ORDER_TYPE_FILLING &fill_mode) const
     {
      const long filling_flags=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);

      if((filling_flags & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
        {
         fill_mode=ORDER_FILLING_FOK;
         return true;
        }

      if((filling_flags & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
        {
         fill_mode=ORDER_FILLING_IOC;
         return true;
        }

      fill_mode=ORDER_FILLING_RETURN;
      return true;
     }

   double            NormalizeLotsToSymbol(const string symbol,const double lots) const
     {
      const double min_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      const double max_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      const double lot_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

      if(min_lot<=0.0 || max_lot<=0.0 || lot_step<=0.0)
         return 0.0;

      double normalized=MathFloor((lots/lot_step)+0.0000001)*lot_step;
      if(normalized<min_lot)
         return 0.0;

      normalized=MathMin(max_lot,normalized);

      return NormalizeDouble(normalized,8);
     }

   bool              BuildMarketRequest(const ExecutionPlan &plan,
                                        const PositionSnapshot &position,
                                        MqlTradeRequest &request,
                                        ExecutionReport &report) const
     {
      ZeroMemory(request);

      report.action=plan.action;
      report.symbol=plan.symbol;

      if(!plan.executable)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_NOOP;
         report.message="Execution plan is not executable";
         return false;
        }

      if(plan.action==EXECUTION_ACTION_HOLD || plan.action==EXECUTION_ACTION_NONE)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_NOOP;
         report.message="Hold/no-op plan does not require OrderSend";
         return false;
        }

      if(plan.action==EXECUTION_ACTION_REJECT)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_NOOP;
         report.message="Rejected plan does not require OrderSend";
         return false;
        }

      ENUM_ORDER_TYPE order_type=(ENUM_ORDER_TYPE)-1;
      switch(plan.action)
        {
         case EXECUTION_ACTION_OPEN_LONG:
         case EXECUTION_ACTION_INCREASE_LONG:
         case EXECUTION_ACTION_REDUCE_SHORT:
         case EXECUTION_ACTION_CLOSE_POSITION:
         case EXECUTION_ACTION_FLIP_TO_LONG:
            order_type=(plan.action==EXECUTION_ACTION_CLOSE_POSITION && plan.current_side==EXPOSURE_SIDE_LONG
                        ? ORDER_TYPE_SELL
                        : ORDER_TYPE_BUY);
            break;

         case EXECUTION_ACTION_OPEN_SHORT:
         case EXECUTION_ACTION_INCREASE_SHORT:
         case EXECUTION_ACTION_REDUCE_LONG:
         case EXECUTION_ACTION_FLIP_TO_SHORT:
            order_type=ORDER_TYPE_SELL;
            break;

         default:
            report.runtime_status=EXECUTION_RUNTIME_STATUS_FAILED;
            report.message="Unsupported execution action";
            return false;
        }

      if(plan.action==EXECUTION_ACTION_CLOSE_POSITION)
        {
         if(plan.current_side==EXPOSURE_SIDE_LONG)
            order_type=ORDER_TYPE_SELL;
         else if(plan.current_side==EXPOSURE_SIDE_SHORT)
            order_type=ORDER_TYPE_BUY;
         else
           {
            report.runtime_status=EXECUTION_RUNTIME_STATUS_NOOP;
            report.message="Close requested while already flat";
            return false;
           }
        }

      const double normalized_volume=NormalizeLotsToSymbol(plan.symbol,plan.delta_lots);
      if(normalized_volume<=0.0)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_FAILED;
         report.message="Request volume normalized to zero for symbol constraints";
         return false;
        }

      ENUM_ORDER_TYPE_FILLING fill_mode;
      if(!ResolveFillMode(plan.symbol,fill_mode))
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_FAILED;
         report.message="Failed to resolve symbol filling mode";
         return false;
        }

      request.action=TRADE_ACTION_DEAL;
      request.magic=m_magic_number;
      request.symbol=plan.symbol;
      request.volume=normalized_volume;
      request.deviation=m_deviation_points;
      request.type=order_type;
      request.type_filling=fill_mode;
      request.type_time=ORDER_TIME_GTC;
      request.comment="ForexMt5EA";
      request.position=position.ticket;
      request.price=(order_type==ORDER_TYPE_BUY
                     ? SymbolInfoDouble(plan.symbol,SYMBOL_ASK)
                     : SymbolInfoDouble(plan.symbol,SYMBOL_BID));

      if(request.price<=0.0)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_FAILED;
         report.message="Failed to resolve current market price for request";
         return false;
        }

      report.request_built=true;
      report.order_type=order_type;
      report.request_volume_lots=request.volume;
      report.request_price=request.price;
      report.request_position_ticket=request.position;
      return true;
     }

   bool              IsAcceptedRetcode(const uint retcode) const
     {
      return retcode==TRADE_RETCODE_DONE
             || retcode==TRADE_RETCODE_DONE_PARTIAL
             || retcode==TRADE_RETCODE_PLACED;
     }

public:
                     Mt5TradeExecutor(void)
     {
      m_magic_number=20260416;
      m_deviation_points=20;
     }

   void              Configure(const long magic_number,const uint deviation_points)
     {
      m_magic_number=magic_number;
      m_deviation_points=deviation_points;
     }

   bool              Execute(const ExecutionPlan &plan,
                             const PositionSnapshot &position,
                             const bool runtime_allowed,
                             ExecutionReport &report) const
     {
      ResetExecutionReport(report);
      report.runtime_allowed=runtime_allowed;
      report.action=plan.action;
      report.symbol=plan.symbol;
      report.executed_at=TimeCurrent();

      MqlTradeRequest request;
      if(!BuildMarketRequest(plan,position,request,report))
         return report.runtime_status==EXECUTION_RUNTIME_STATUS_NOOP;

      if(!runtime_allowed)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_BLOCKED_BY_GUARD;
         report.message="Runtime guard blocked live OrderSend";
         return false;
        }

      MqlTradeResult result;
      ZeroMemory(result);

      report.attempted=true;
      const bool send_ok=OrderSend(request,result);

      report.request_sent=send_ok;
      report.result_retcode=result.retcode;
      report.result_deal=result.deal;
      report.result_order=result.order;
      report.executed_at=TimeCurrent();

      if(!send_ok)
        {
         report.runtime_status=EXECUTION_RUNTIME_STATUS_FAILED;
         report.message=StringFormat("OrderSend returned false, retcode=%u",result.retcode);
         return false;
        }

      report.result_accepted=IsAcceptedRetcode(result.retcode);
      report.runtime_status=(report.result_accepted
                             ? EXECUTION_RUNTIME_STATUS_SENT
                             : EXECUTION_RUNTIME_STATUS_FAILED);
      report.message=StringFormat("OrderSend retcode=%u",result.retcode);
      return report.result_accepted;
     }
  };

#endif
