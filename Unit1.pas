unit Unit1;
interface
uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, StrUtils, ComCtrls,
  winspool, printers,
  ADODB, Unit2;

const
  PrinterDefaults: TPrinterDefaults = (pDatatype: nil; pDevMode: nil; DesiredAccess: PRINTER_ACCESS_USE or PRINTER_ACCESS_ADMINISTER);


type
  // een record voor elke gevonden printer
  TPrinterRec = record
    Handle : THandle;
    Name : string;
    Device,
    Driver,
    Port: array[0..255] of char;
  end;

  // een record voor elke printjob met data die ik wil afbeelden in de listview
  TPrintJobRec = record
    PrinterHandle: THandle;
    JobID: dword;
    Owner: string;
    PagesPrinted,
    TotalPages: dword;
    Document: string;
    Submitted: TDateTime;
    StatusCode: dword;
    Status: string;
  end;

  // het formulier
  TForm1 = class(TForm)
    Memo1: TMemo;
    bPrintJobs: TButton;
    bMonitor: TButton;
    cbPrinters: TComboBox;
    bPrintProcessors: TButton;
    bPauseJob: TButton;
    bResumeJob: TButton;
    bCancelJob: TButton;
    lvPrintJobs: TListView;
    lJobID: TLabel;
    Label2: TLabel;
    bCancelJobs: TButton;
    GroupBox1: TGroupBox;
    bPrintPRN: TButton;
    ePRN: TEdit;
    cbPRNPrinter: TComboBox;
    Label1: TLabel;
    Label3: TLabel;
    Memo2: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure bPrintProcessorsClick(Sender: TObject);
    procedure bMonitorClick(Sender: TObject);
    procedure cbPrintersChange(Sender: TObject);
    procedure lvPrintJobsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure bPrintPRNClick(Sender: TObject);
    procedure bPrintJobsClick(Sender: TObject);
    procedure bPauseJobClick(Sender: TObject);
    procedure bResumeJobClick(Sender: TObject);
    procedure bCancelJobClick(Sender: TObject);
    procedure bCancelJobsClick(Sender: TObject);
  private
    // De thread om op een printJob-verandering te wachten
    WT: TWaitThread;
    //
    {procedure WM_SpoolerStatus(var Msg : TWMSPOOLERSTATUS); message WM_SPOOLERSTATUS;}
    function ShowPChar(p: PChar): PChar;
    function GetPrinterHandle(printerName: string): THandle;
    function GetCurrentPrinterHandle: THandle;
    function GetPrinterListIndex(PrinterHandle: THandle) : integer;
    function SpoolFile(hPrinter: THandle; const FileName: string) : Integer;
    function getServerName(PrinterIndex: integer): PChar;  //local printer => ''
    function StatusString(status: cardinal): string;
    procedure setPrintJob(state: dword);
  public
    // Een lijst van belangrijke eigenschappen voor alle aangesloten printers
    PrinterList : array of TPrinterRec;
    //
    procedure insertDB(aJobID,aUser,aDocTitle,aCreationDate,aPages,aTargetDevice,aFileName: string);
    // systemtime naar timezone tijd
    function UTCTimeToLocalTime(UTC: TSystemTime) : TDateTime;
    // info opvragen van een printjob
    function GetJobInfo(PrinterHandle: THandle; JobID: dword) : JOB_INFO_2;
    // een regel toevoegen aan de listview voor printjobs
    procedure ListPrintJob(JobInfo2: JOB_INFO_2); overload;
    procedure ListPrintJob(PNID: TPrinterNotifyInfoData); overload;
  end;

var
  Form1: TForm1;

implementation
{$R *.dfm}




{procedure TForm1.WM_SpoolerStatus(var Msg : TWMSPOOLERSTATUS);
begin
  Memo1.lines.add(IntToStr(msg.JobsLeft) + ' Jobs currently in spooler');
  msg.Result := 0;
end;}



function TForm1.UTCTimeToLocalTime(UTC: TSystemTime): TDateTime;
var TZ: TTimeZoneInformation;
    LT: TSystemTime;
begin
  GetTimeZoneInformation(TZ);
  if SystemTimeToTzSpecificLocalTime(@TZ, UTC, LT) then
    Result := SystemTimeToDateTime(LT)
  else
    Result := SystemTimeToDateTime(UTC);
end;


function TForm1.ShowPChar(p: PChar): PChar;
begin
  if not Assigned(p) then Result := 'Nil'
                     else Result := p;
end;


function TForm1.StatusString(status: cardinal): string;
var s: string;
  procedure addS(sa: string);
  begin
    if s<>'' then s := s +' - '+ sa
             else s := sa;
  end;
begin
  s := '';
  if status = JOB_POSITION_UNSPECIFIED then addS('Position unspecified');
  if (status and JOB_STATUS_ERROR)>0 then addS('Error');
  if (status and JOB_STATUS_PAUSED)>0 then addS('Paused');
  if (status and JOB_STATUS_OFFLINE)>0 then addS('Offline');
  if (status and JOB_STATUS_PAPEROUT)>0 then addS('Out of paper');
  if (status and JOB_STATUS_BLOCKED_DEVQ)>0 then addS('Driver error');
  if (status and JOB_STATUS_USER_INTERVENTION)>0 then addS('User intervention');
  if (status and JOB_STATUS_RESTART)>0 then addS('Restarted');
  if (status and JOB_STATUS_SPOOLING)>0 then addS('Spooling');
  if (status and JOB_STATUS_PRINTING)>0 then addS('Printing');
  if (status and JOB_STATUS_PRINTED)>0 then addS('Printed');
  if (status and JOB_STATUS_DELETING)>0 then addS('Deleting');
  if (status and JOB_STATUS_DELETED)>0 then addS('Deleted');
  Result := s;
end;


function TForm1.GetCurrentPrinterHandle: THandle;
var Device, Driver, Port: array[0..255] of char;
    hDeviceMode: THandle;
begin
  Printer.GetPrinter(Device, Driver, Port, hDeviceMode);
  if not OpenPrinter(@Device, Result, @PrinterDefaults) then RaiseLastOSError;
end;

// Resulteer de handle van een opgegeven printernaam
function TForm1.GetPrinterHandle(printerName: string): THandle;
var i: integer;
    HuidigePrinter: integer;
begin
  HuidigePrinter := Printer.PrinterIndex;
  for i:=0 to Printer.Printers.Count-1 do
    if Printer.Printers[i] = printerName then begin
      Printer.PrinterIndex := i;
      Result := GetCurrentPrinterHandle;
      break;
    end;
  // De huidige printer selecteren/herstellen
  Printer.PrinterIndex := HuidigePrinter;
  GetCurrentPrinterHandle;
end;

function TForm1.GetPrinterListIndex(PrinterHandle: THandle): integer;
var i: integer;
begin
  Result := -1;
  for i:=0 to Length(PrinterList)-1 do
    if PrinterList[i].Handle = PrinterHandle then begin
      Result := i;
      break;
    end;
end;


function TForm1.getServerName(PrinterIndex: integer): PChar;
var s: string;
begin
  s := Printer.Printers[Printer.PrinterIndex];
  if copy(s,1,2) = '\\' then begin
    if PosEx('\',s,3)=0 then
      Result := PChar('')
    else
      Result := PChar(copy(s,1,PosEx('\',s,3)-1));
  end else
    Result := PChar('');
//    result := '\\192.168.2.3'
end;






procedure TForm1.FormCreate(Sender: TObject);
var i: integer;
    HuidigePrinter: integer;
    hDeviceMode: THandle;
begin
  // De huidige printer
  cbPrinters.Items.Assign(Printer.Printers);
  cbPrinters.ItemIndex := Printer.PrinterIndex;
  // De printer voor .PRN-files (NIET redirected)
  cbPRNPrinter.Items.Assign(Printer.Printers);
  cbPRNPrinter.ItemIndex := Printer.PrinterIndex;
  // De lijst met printers aanmaken (incl Handles)
  HuidigePrinter := Printer.PrinterIndex;  //huidige printer opvragen..
  SetLength(PrinterList, Printer.Printers.Count);
  for i:=0 to Printer.Printers.Count-1 do begin
    // huidige printer instellen
    Printer.PrinterIndex := i;
    // naam opvragen
    PrinterList[i].Name := Printer.Printers[i];
    // devicenaam opvragen
    Printer.GetPrinter(PrinterList[i].Device, PrinterList[i].Driver, PrinterList[i].Port, hDeviceMode);
    // handle opvragen..
    if not OpenPrinter(@PrinterList[i].Device, PrinterList[i].Handle, @PrinterDefaults) then RaiseLastOSError;
    try
    finally
      ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
    end;
  end;
  Printer.PrinterIndex := HuidigePrinter;  //huidige printer herstellen..

  // de huidige printer openen..
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;

  // De WaitForPrintJob-thread (suspended) starten
  // Deze thread detecteert veranderingen in printJobs..
  WT := TWaitThread.Create(true);
  GetLocaleFormatSettings($0413,WT.FS);    //Dutch
  WT.hPrinter := PrinterList[Printer.PrinterIndex].Handle;
  WT.FreeOnTerminate := true;
  WT.Resume;

end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  // De WaitForPrintJob-thread stoppen en vrijgeven
  WT.Terminate;
  // de huidig geopende printer weer sluiten
  try
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  except
  end;
  // De interne lijst met printers (en handles) weer wissen
  SetLength(PrinterList, 0);
end;




procedure TForm1.cbPrintersChange(Sender: TObject);
begin
  // de huidig geopende printer weer sluiten
  try
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  except
  end;

  Printer.PrinterIndex := cbPrinters.ItemIndex;
  Memo1.lines.add('Huidige printer: '+ Printer.Printers[Printer.PrinterIndex]);
  lvPrintJobs.Items.Clear;

  // de nieuw gekozen printer openen..
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;

  // de thread printer verversen..
  WT.hPrinter := PrinterList[Printer.PrinterIndex].Handle;
end;



function TForm1.GetJobInfo(PrinterHandle: THandle; JobID: dword): JOB_INFO_2;
var bytesNeeded: dword;
    i: integer;
begin
  i := GetPrinterListIndex(PrinterHandle);
  if i = -1 then begin
    Result.JobId := 0; // niet gelukt..
    Exit;
  end;
  //
  if not OpenPrinter(@PrinterList[i].Device, PrinterHandle, @PrinterDefaults) then RaiseLastOSError;
  try
    if not GetJob(PrinterHandle, JobID, 2, @Result, SizeOf(Result), @bytesNeeded) then
      Result.JobId := 0; // niet gelukt..
  finally
    ClosePrinter(PrinterHandle);
  end;
end;


procedure TForm1.bPrintJobsClick(Sender: TObject);
type TJobs  = array [0..100] of JOB_INFO_2;
     PJobs = ^TJobs;
var bytesNeeded, numJobs, i, si: Cardinal;
    pJ: PJobs;
    s: string;
    Li, selected : TListItem;
    DT: TDateTime;
begin
  // de evt. geselecteerde regel onthouden..
  si := lvPrintJobs.ItemIndex;
  if si <> -1 then selected := lvPrintJobs.Items[lvPrintJobs.ItemIndex];
  memo1.Lines.Clear;
  lvPrintJobs.Items.Clear;
  //
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;
  try
    EnumJobs(PrinterList[Printer.PrinterIndex].Handle, 0, 100, 2, nil, 0, bytesNeeded, numJobs);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen print-opdrachten in de wachtrij')
    else begin
      pJ := AllocMem(bytesNeeded);
      try
        if not EnumJobs(PrinterList[Printer.PrinterIndex].Handle, 0, 100, 2, pJ, bytesNeeded, bytesNeeded, numJobs) then RaiseLastOSError;
        // jobs afbeelden
        for i:=0 to Pred(numJobs) do ListPrintJob(pJ[i]);
        // het geselecteerde item weer selecteren..
        if si <> -1 then lvPrintJobs.ItemIndex := lvPrintJobs.Items.IndexOf(selected);
      finally
        FreeMem(pJ);
      end;
    end;
  finally
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  end;
end;


procedure TForm1.setPrintJob(state: dword);
var b: boolean;
begin
  if lJobID.Caption='' then exit;
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;
  try
    try
      b := SetJob(PrinterList[Printer.PrinterIndex].Handle, StrToInt(lJobID.Caption), 0, nil, state);
    except
    end;
  finally
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
    // De huidige wachtrij-inhoud afbeelden
    bPrintJobsClick(nil);
  end;
end;


procedure TForm1.lvPrintJobsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  bPauseJob.Enabled := selected;
  bResumeJob.Enabled := selected;
  bCancelJob.Enabled := selected;
  if selected then lJobID.Caption := Item.Caption
              else lJobID.Caption := '';
end;


// Een print-opdracht pauzeren
procedure TForm1.bPauseJobClick(Sender: TObject);
begin
  setPrintJob(JOB_CONTROL_PAUSE);
end;


// Een print-opdracht hervatten
procedure TForm1.bResumeJobClick(Sender: TObject);
begin
  setPrintJob(JOB_CONTROL_RESUME);
end;


// Een print-opdracht wissen uit de wachtrij
procedure TForm1.bCancelJobClick(Sender: TObject);
begin
  setPrintJob(JOB_CONTROL_CANCEL);
end;


// Alle print-opdrachten uit de wachtrij wissen
procedure TForm1.bCancelJobsClick(Sender: TObject);
var hPrinter: THandle;
begin
  {hPrinter := GetCurrentPrinterHandle;}
  hPrinter := PrinterList[Printer.PrinterIndex].Handle;
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, hPrinter, @PrinterDefaults) then RaiseLastOSError;
  try
    if not WinSpool.SetPrinter(hPrinter, 0, nil, PRINTER_CONTROL_PURGE ) then RaiseLastOSError
  finally
    ClosePrinter(hPrinter);
  end;
  // De huidige wachtrij-inhoud afbeelden
  bPrintJobsClick(nil);
end;





function TForm1.SpoolFile(hPrinter: THandle; const FileName: string) : Integer;
var Buffer: record
      JobInfo: record // ADDJOB_INFO_1
        Path: PCHAR;
        JobID: DWORD;
      end;
      PathBuffer: array[0..255] of char;
    end;
    SizeNeeded: DWORD;
begin
  Result := 2;  //file not found
  if not FileExists(FileName) then exit;
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;
  try
    if AddJob(hPrinter, 1, @Buffer, SizeOf(Buffer), SizeNeeded) then
      if CopyFile(PChar(FileName), Buffer.JobInfo.Path, true) then
        if ScheduleJob(hPrinter, Buffer.JobInfo.JobID) then
          Result := 0
        else
          Result := GetLastError;
  finally
    {ClosePrinter(hPrinter);}
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  end;
end;

procedure TForm1.bPrintPRNClick(Sender: TObject);
begin
  // de aangegeven file direct in de printer-buffer plaatsen
  if SpoolFile(PrinterList[cbPRNPrinter.ItemIndex].Handle, ePRN.Text)<>0 then
    ShowMessage('De .PRN file is NIET in de printer-wachtrij geplaatst !');
end;






procedure TForm1.bPrintProcessorsClick(Sender: TObject);
type TProcs  = array[0..1000] of PRINTPROCESSOR_INFO_1;
     PProcs = ^TProcs;
     TProcsDir = array[0..1000] of char;
var bytesNeeded, numProcs, i: Cardinal;
    pP: PProcs;
    PD: TProcsDir;
begin
  memo1.Lines.Clear;
  {lvPrintJobs.Items.Clear;}
  //
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;
  //
  try
    EnumPrintProcessors(getServerName(Printer.PrinterIndex), PChar(''), 1, pP, 0, bytesNeeded, numProcs);
    pP := AllocMem(bytesNeeded);
    try
      if not EnumPrintProcessors(getServerName(Printer.PrinterIndex), PChar(''), 1, pP, bytesNeeded, bytesNeeded, numProcs) then RaiseLastOSError;
      if numProcs = 0 then
        memo1.Lines.Add('Geen print-processors voor deze printer')
      else
        for i:=0 to Pred(numProcs) do begin
          memo1.lines.Add(Format('Print-Processor: %s', [ShowPChar(pP^[i].pName)]));
          // de print-processor directory opvragen
          if GetPrintProcessorDirectory(getServerName(Printer.PrinterIndex), '', 1, @PD, SizeOf(TProcsDir), bytesNeeded) then
            memo1.lines.Add('Print-Processor-Dir: '+ pD);
        end;
    finally
      FreeMem(pP);
    end;
  finally
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  end;
end;


procedure TForm1.bMonitorClick(Sender: TObject);
type TMonitors = array[0..1000] of TMonitorInfo1A;
     PMonitors = ^TMonitors;
var pM : PMonitors;
    bytesNeeded, numMonitors, i : cardinal;
    s : PChar;
begin
  memo1.Lines.Clear;
  {lvPrintJobs.Items.Clear;}
  //
  if not OpenPrinter(@PrinterList[Printer.PrinterIndex].Device, PrinterList[Printer.PrinterIndex].Handle, @PrinterDefaults) then RaiseLastOSError;
  try
    s := PChar(Printer.Printers[Printer.PrinterIndex]);
    EnumMonitors(s, 1, nil, 0, bytesNeeded, numMonitors);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen monitors voor deze printer')
    else begin
      pM := AllocMem(bytesNeeded);
      try
        if not EnumMonitors(s, 1, pM, bytesNeeded, bytesNeeded, numMonitors) then RaiseLastOSError;
        for i := 0 to Pred(numMonitors) do memo1.lines.add(ShowPChar(pM^[i].pName));
      finally
        FreeMem(pM);
      end;
    end;
  finally
    ClosePrinter(PrinterList[Printer.PrinterIndex].Handle);
  end;
end;




procedure TForm1.insertDB(aJobID,aUser,aDocTitle,aCreationDate,aPages,aTargetDevice,aFileName: string);
var CN: TADOConnection;
    SQLquery: string;
begin
  try
    try
      // Een connectie-object instantiëren
      CN := TADOConnection.Create(nil);
      CN.ConnectionString := 'DSN=ZwijsenPrintJobs;DATABASE=PrintJobs;';
      // Open de connectie met een correcte naam/wachtwoord combinatie
      CN.LoginPrompt := false;
      CN.Open('admin','');
    except
      if not CN.Connected then begin
        CN.Free;
        memo1.lines.add('fout-1: Unit1.insertDB');
        exit;
      end;
    end;

    // Een record toevoegen aan de DB
    SQLquery := 'INSERT INTO PrintJobs (JobID,User,Title,CreationDate,Pages,TargetDevice,FileName) VALUES (';
    SQLquery := SQLquery + aJobID +',';
    SQLquery := SQLquery + QuotedStr(aUser) +',';
    SQLquery := SQLquery + QuotedStr(aDocTitle) +',';
    SQLquery := SQLquery + QuotedStr(aCreationDate) +',';
    SQLquery := SQLquery + aPages +',';
    SQLquery := SQLquery + QuotedStr(aTargetDevice) +',';
    SQLquery := SQLquery + QuotedStr(aFileName) +')';
    try
      CN.Execute(SQLquery,cmdText);
    except
      memo1.lines.add('fout-2: Unit1.insertDB');
    end;
  finally
    // De DB sluiten
    if CN.Connected then CN.Close;
    CN.Free;
    // wat info afbeelden in de memo
    memo1.lines.Clear;
    memo1.lines.add(SQLquery);
  end;
end;


procedure TForm1.ListPrintJob(JobInfo2: JOB_INFO_2);
var Li, selected : TListItem;
    DT: TDateTime;
    JobID, UserName, printed, Document, Submitted, status, machine, docsize: string;
    i: integer;
    addLI: boolean;
begin
  // JobID
  JobID := IntToStr(JobInfo2.JobID);
  // username
  UserName := ShowPChar(JobInfo2.pUserName);
  // PagesPrinted/TotalPages
  printed := IntToStr(JobInfo2.PagesPrinted) +'/'+ IntToStr(JobInfo2.TotalPages);
  // document
  Document := ShowPChar(JobInfo2.pDocument);
  // submitted
  DT := UTCTimeToLocalTime(JobInfo2.Submitted);
  Submitted := DateToStr(DT) +' '+ TimeToStr(DT);
  // status
  if JobInfo2.pStatus = nil then begin
    status := StatusString(JobInfo2.Status);
(*
    // is de job verwijderd uit de queue?
    if (JobInfo2.Status and JOB_STATUS_DELETED)>0 then begin
      for i:=0 to lvPrintJobs.Items.Count-1 do
        if lvPrintJobs.Items[i].Caption = JobID then begin
          lvPrintJobs.Items.Delete(i);
          exit;
        end;
    end;
*)
  end else begin
    status := ShowPChar(JobInfo2.pStatus);
  end;
  status := Format('(%d) %s', [JobInfo2.Status, status]);
  // machinename
  machine := JobInfo2.pMachineName;
  // size
  docsize := IntToStr(JobInfo2.Size);

  // test of er al een regel bestaat voor deze printJob
  addLI := true;
  for i:=0 to lvPrintJobs.Items.Count-1 do begin
    if lvPrintJobs.Items[i].Caption = JobID then begin
      Li := lvPrintJobs.Items[i];
      Li.SubItems[0] := UserName;
      Li.SubItems[1] := printed;
      Li.SubItems[2] := Document;
      Li.SubItems[3] := Submitted;
      Li.SubItems[4] := status;
      Li.SubItems[5] := machine;
      Li.SubItems[6] := docsize;
      addLI := false;
      break;
    end;
  end;
  // nieuw item toevoegen?
  if addLI then begin
    // toevoegen aan de listview..
    Li := lvPrintJobs.Items.Add;
    Li.Caption := JobID;
    Li.SubItems.Add(UserName);
    Li.SubItems.Add(printed);
    Li.SubItems.Add(Document);
    Li.SubItems.Add(Submitted);
    Li.SubItems.Add(status);
    Li.SubItems.Add(machine);
    Li.SubItems.Add(docsize);
  end;
end;

procedure TForm1.ListPrintJob(PNID: TPrinterNotifyInfoData);
var JobID, i: integer;
    Li: TListItem;
begin
  // de printjob-ID
  JobID := PNID.Id;
  // bepaal het listview-item
  Li := nil;
  for i:=0 to lvPrintJobs.Items.Count-1 do begin
    if lvPrintJobs.Items[i].Caption = IntToStr(JobID) then begin
      Li := lvPrintJobs.Items[i];
      break;
    end;
  end;
  if not assigned(Li) then Exit;
  // het veld dat is veranderd
  case PNID.Field of
    JOB_NOTIFY_FIELD_USER_NAME           : Li.SubItems[0] := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_PAGES_PRINTED       : Li.SubItems[1] := IntToStr(PNID.NotifyData.adwData[0]) +'/'+ Copy(Li.SubItems[1], Pos('/',Li.SubItems[1])+1, Length(Li.SubItems[1]));
    JOB_NOTIFY_FIELD_TOTAL_PAGES         : Li.SubItems[1] := '/'+ IntToStr(PNID.NotifyData.adwData[0]);
    JOB_NOTIFY_FIELD_DOCUMENT            : Li.SubItems[2] := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_SUBMITTED           : Li.SubItems[3] := '';
    JOB_NOTIFY_FIELD_STATUS              : Li.SubItems[4] := StatusString(PNID.NotifyData.adwData[0]);
    JOB_NOTIFY_FIELD_STATUS_STRING       : Li.SubItems[4] := PChar(PNID.NotifyData.Data.pBuf);
(*
    JOB_NOTIFY_FIELD_PRINTER_NAME        : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_MACHINE_NAME        : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_PORT_NAME           : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_NOTIFY_NAME         : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_DATATYPE            : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_PRINT_PROCESSOR     : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_PARAMETERS          : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_DRIVER_NAME         : s := PChar(PNID.NotifyData.Data.pBuf);
    JOB_NOTIFY_FIELD_DEVMODE             : begin end;
    JOB_NOTIFY_FIELD_SECURITY_DESCRIPTOR : begin end;
    JOB_NOTIFY_FIELD_PRIORITY            : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_POSITION            : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_START_TIME          : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_UNTIL_TIME          : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_TIME                : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_TOTAL_BYTES         : dw := PNID.NotifyData.adwData[0];
    JOB_NOTIFY_FIELD_BYTES_PRINTED       : dw := PNID.NotifyData.adwData[0];
*)
  end;
end;


end.
