#ifndef FOREXMT5EA_STORAGE_FILESTATESTORE_MQH
#define FOREXMT5EA_STORAGE_FILESTATESTORE_MQH

#include "../Domain/StrategyContracts.mqh"

class FileStateStore
  {
private:
   string            m_root;

   bool              EnsureFolders(void)
     {
      ResetLastError();
      const bool root_created=FolderCreate(m_root,FILE_COMMON);
      const int root_error=GetLastError();
      ResetLastError();
      const bool state_created=FolderCreate(m_root+"\\state",FILE_COMMON);
      const int state_error=GetLastError();
      ResetLastError();
      const bool root_ready=root_created || root_error==ERR_FILE_ALREADY_EXISTS;
      const bool state_ready=state_created || state_error==ERR_FILE_ALREADY_EXISTS;
      return root_ready && state_ready;
     }

public:
                     FileStateStore(const string root="ForexMt5EA")
     {
      m_root=root;
     }

   bool              SaveRatings(const StrategyRating &ratings[])
     {
      if(!EnsureFolders())
         return false;

      const int handle=FileOpen(m_root+"\\ratings.csv",FILE_COMMON|FILE_WRITE|FILE_CSV|FILE_ANSI,';');
      if(handle==INVALID_HANDLE)
         return false;

      FileWrite(handle,"strategy_id","score_bps","weight_bps","updated_at");
      const int count=ArraySize(ratings);
      for(int i=0;i<count;i++)
         FileWrite(handle,(int)ratings[i].strategy_id,ratings[i].score_bps,ratings[i].weight_bps,(long)ratings[i].updated_at);

      FileClose(handle);
      return true;
     }

   bool              LoadRatings(StrategyRating &ratings[])
     {
      ResetLastError();
      const int handle=FileOpen(m_root+"\\ratings.csv",FILE_COMMON|FILE_READ|FILE_CSV|FILE_ANSI,';');
      if(handle==INVALID_HANDLE)
         return false;

      ArrayResize(ratings,0);

      if(!FileIsEnding(handle))
        {
         FileReadString(handle);
         FileReadString(handle);
         FileReadString(handle);
         FileReadString(handle);
        }

      while(!FileIsEnding(handle))
        {
         StrategyRating rating;
         ResetRating(rating,STRATEGY_ID_NONE);

         const string id_text=FileReadString(handle);
         if(id_text=="")
            break;

         rating.strategy_id=(ENUM_STRATEGY_ID)StringToInteger(id_text);
         rating.score_bps=(int)StringToInteger(FileReadString(handle));
         rating.weight_bps=(int)StringToInteger(FileReadString(handle));
         rating.updated_at=(datetime)StringToInteger(FileReadString(handle));

         const int next_index=ArraySize(ratings);
         ArrayResize(ratings,next_index+1);
         ratings[next_index]=rating;
        }

      FileClose(handle);
      return true;
     }

   bool              SaveStrategyState(const string strategy_key,const string payload)
     {
      if(!EnsureFolders())
         return false;

      const int handle=FileOpen(m_root+"\\state\\"+strategy_key+".txt",FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return false;

      FileWriteString(handle,payload);
      FileClose(handle);
      return true;
     }

   bool              LoadStrategyState(const string strategy_key,string &payload)
     {
      payload="";
      ResetLastError();
      const int handle=FileOpen(m_root+"\\state\\"+strategy_key+".txt",FILE_COMMON|FILE_READ|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return false;

      payload=FileReadString(handle);
      FileClose(handle);
      return true;
     }
  };

#endif
