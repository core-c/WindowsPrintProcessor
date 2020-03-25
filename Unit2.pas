unit Unit2;
interface
uses classes, SysUtils, WinSpool, Printers;


type
  TWaitThread = class(TThread)
  private
    JobID: cardinal;
    PNID: TPrinterNotifyInfoData;
    //Synchronize methoden
    procedure RefreshPrintJob;
    procedure RefreshPrintJobs;
    procedure test;
    procedure test2;
  public
    FS: TFormatSettings;  //tbv Datum-conversie -> string
    hPrinter: THandle;
  protected
    procedure Execute; override;
    procedure StorePrintJob;
  end;


implementation
uses windows,Unit1;




procedure TWaitThread.Execute;
const
  // ik wil ingelicht worden als de printer weer een pagina heeft afgedrukt..
  PNOTFields_Printer : array[0..0] of word = (PRINTER_NOTIFY_FIELD_CJOBS);
  PNOTFields_Job : array[0..0] of word = (JOB_NOTIFY_FIELD_PAGES_PRINTED);
var changeObj: cardinal;
    pdwChange: dword;
    flags: cardinal;
    WFSO: cardinal;
    i,j: integer;
    PNOT: array[0..1] of TPrinterNotifyOptionsType; //printer,job
    PNO: TPrinterNotifyOptions;
    PPNO: pointer;
    PNI: TPrinterNotifyInfo;
    PPNI: pointer;
begin
  inherited;
  repeat
    try
      // PrinterNotifyOptionsType
      // job_notify
      PNOT[0].wType := JOB_NOTIFY_TYPE;             // veranderingen in print-jobs constateren
      PNOT[0].Count := Length(PNOTFields_Job);      // fields bevat 1 element te testen
      PNOT[0].pFields := @PNOTFields_Job;           // de fields
      // printer_notify
      PNOT[1].wType := PRINTER_NOTIFY_TYPE;         // veranderingen in printer constateren
      PNOT[1].Count := Length(PNOTFields_Printer);  // fields bevat 1 element te testen
      PNOT[1].pFields := @PNOTFields_Printer;       // de fields
      // PrinterNotifyOptions
      PNO.Version := 2;                             // altijd 2
      PNO.Flags := PRINTER_NOTIFY_OPTIONS_REFRESH;
      PNO.Count := Length(PNOT);
      PNO.pTypes := @PNOT[0];                       // pointer naar de PrinterNotifyOptionsType
      // PrinterNotifyOptions pointer
      PPNO := @PNO;
      // PrinterNotifyInfo pointer
      PPNI := @PNI;
      //
      pdwChange := 0;
      flags :=  PRINTER_CHANGE_ADD_JOB or PRINTER_CHANGE_SET_JOB or PRINTER_CHANGE_WRITE_JOB or PRINTER_CHANGE_DELETE_JOB;
      changeObj := FindFirstPrinterChangeNotification(hPrinter, flags, 0, PPNO);
      if changeObj <> INVALID_HANDLE_VALUE then begin
        WFSO := WaitForSingleObject(changeObj, INFINITE);
        if  WFSO = WAIT_OBJECT_0 then
        if FindNextPrinterChangeNotification(changeObj, pdwChange, PPNO, PPNI) then begin

          //pdwChange geeft de verandering aan (job-flags)
          {if (pdwChange and PRINTER_CHANGE_ADD_JOB)>0 then Synchronize(RefreshPrintJobs);
          if (pdwChange and PRINTER_CHANGE_SET_JOB)>0 then begin
            //
          end;
          if (pdwChange and PRINTER_CHANGE_WRITE_JOB)>0 then begin
            //
          end;
          if (pdwChange and PRINTER_CHANGE_DELETE_JOB)>0 then Synchronize(RefreshPrintJobs);}
          // overall job_change
          if (pdwChange and PRINTER_CHANGE_JOB)>0 then Synchronize(RefreshPrintJobs);

          // als er een verandering is, dan alle veranderingen doorlopen
          if pdwChange>0 then
          // PPNI bevat een pointer die verwijst naar een PRINTER_NOTIFY_INFO record..
          for j:=0 to TPrinterNotifyInfo(PPNI^).Count-1 do begin
            // de printjob waavan iets is veranderd..
            JobID := TPrinterNotifyInfo(PPNI^).aData[j].Id;
            // de printer-notify-info-data
            PNID := TPrinterNotifyInfo(PPNI^).aData[j];
(*
            // een printer_notify?
            if TPrinterNotifyInfo(PPNI^).aData[j].wType = PRINTER_NOTIFY_TYPE then begin
              // welk veld is veranderd?
              case TPrinterNotifyInfo(PPNI^).aData[j].Field of
                PRINTER_NOTIFY_FIELD_CJOBS : Synchronize(RefreshPrintJobs);
              end;
            end else
*)
            // een job_notify?
            if TPrinterNotifyInfo(PPNI^).aData[j].wType = JOB_NOTIFY_TYPE then begin
              // welk veld is veranderd?
              case PNID.Field of
                JOB_NOTIFY_FIELD_PAGES_PRINTED       : Synchronize(RefreshPrintJob);
  (*
                JOB_NOTIFY_FIELD_PRINTER_NAME        : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_MACHINE_NAME        : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_PORT_NAME           : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_USER_NAME           : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_NOTIFY_NAME         : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_DATATYPE            : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_PRINT_PROCESSOR     : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_PARAMETERS          : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_DRIVER_NAME         : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_DEVMODE             :
                JOB_NOTIFY_FIELD_STATUS              : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_STATUS_STRING       : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_SECURITY_DESCRIPTOR :
                JOB_NOTIFY_FIELD_DOCUMENT            : PChar(PNID.NotifyData.Data.pBuf);
                JOB_NOTIFY_FIELD_PRIORITY            : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_POSITION            : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_SUBMITTED           :
                JOB_NOTIFY_FIELD_START_TIME          : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_UNTIL_TIME          : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_TIME                : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_TOTAL_PAGES         : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_PAGES_PRINTED       : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_TOTAL_BYTES         : PNID.NotifyData.adwData[0];
                JOB_NOTIFY_FIELD_BYTES_PRINTED       : PNID.NotifyData.adwData[0];
  *)
              end;
            end;
          end;
        end;
      end;
    finally
      if Assigned(PPNI) then FreePrinterNotifyInfo(PPNI);
      // Het changeObject weer vrijgeven
      try
        FindClosePrinterChangeNotification(changeObj);
      except
      end;
    end;
  until Terminated;
end;


procedure TWaitThread.StorePrintJob;
type TJobs  = array [0..1000] of JOB_INFO_1;
     PJobs = ^TJobs;
var bytesNeeded, numJobs, i: Cardinal;
    pJ: PJobs;
    s: string;
begin
  try
    try
      EnumJobs(hPrinter, 0, 1000, 1, nil, 0, bytesNeeded, numJobs);
      if bytesNeeded > 0 then begin
        pJ := AllocMem(bytesNeeded);
        try
          if not EnumJobs(hPrinter, 0, 1000, 1, pJ, bytesNeeded, bytesNeeded, numJobs) then RaiseLastOSError;
          // job info opvragen
          // bewaar de info van de printJob in de Access-DB
          i := numJobs-1;
(*
          Form1.insertDB(IntToStr(pJ^[i].JobID),
                         pJ^[i].pUserName,
                         pJ^[i].pDocument,
                         DateTimeToStr(SystemTimeToDateTime(pJ^[i].Submitted),FS),  //'aCreationDate',
                         IntToStr(TotalPages), //IntToStr(pJ^[i].TotalPages),
                         pJ^[i].pPrinterName,
                         'C:\'+ IntToStr(pJ^[i].JobID) +'__'+ pJ^[i].pUserName +'__'+ IntToStr(TotalPages) +'.prn');
*)
        finally
          FreeMem(pJ);
        end;
      end;
    finally
    end;
  except
  end;
end;


procedure TWaitThread.RefreshPrintJob;
var JobInfo: JOB_INFO_2;
begin
  JobInfo := Form1.GetJobInfo(hPrinter,JobID);
  if JobInfo.JobId <> 0 then //gelukt?
    Form1.ListPrintJob(JobInfo);
end;

procedure TWaitThread.RefreshPrintJobs;
begin
  Form1.bPrintJobsClick(nil);
end;


procedure TWaitThread.test;
begin
  Form1.Memo2.Lines.Add('JobID = '+ IntToStr(JobID) +', PagesPrinted = ');
end;

procedure TWaitThread.test2;
begin
  Form1.Memo2.Lines.Add('printer_notify' +', PagesPrinted = ');
end;


end.
