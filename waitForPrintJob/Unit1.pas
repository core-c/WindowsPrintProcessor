unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, AppEvnts, StdCtrls, StrUtils,
  winspool, printers, Sockets;

type
  TForm1 = class(TForm)
    ApplicationEvents1: TApplicationEvents;
    Memo1: TMemo;
    bPrintJobs: TButton;
    bMonitor: TButton;
    cbPrinters: TComboBox;
    bPrintPRN: TButton;
    ePRN: TEdit;
    bPrintProcessors: TButton;
    Button1: TButton;
    bDriver: TButton;
    bPorts: TButton;
    Label1: TLabel;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
    procedure cbPrintersChange(Sender: TObject);
    procedure bPrintPRNClick(Sender: TObject);
    procedure bPrintJobsClick(Sender: TObject);
    procedure bPrintProcessorsClick(Sender: TObject);
    procedure bMonitorClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure bDriverClick(Sender: TObject);
    procedure bPortsClick(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    procedure WM_SpoolerStatus(var Msg : TWMSPOOLERSTATUS); message WM_SPOOLERSTATUS;
    function ShowPChar(p: PChar): PChar;
    function GetCurrentPrinterHandle: THandle;
    procedure KillJobsOnCurrentPrinter;
    procedure waitChange;
    function SpoolFile(const FileName: String): Integer;
    function getServerName(PrinterIndex: integer): PChar;  //local printer => ''
  end;

var
  Form1: TForm1;

implementation
{$R *.dfm}


procedure TForm1.FormCreate(Sender: TObject);
begin
  cbPrinters.Items.Assign(Printer.Printers);
  cbPrinters.ItemIndex := Printer.PrinterIndex
end;


procedure TForm1.cbPrintersChange(Sender: TObject);
begin
  Printer.PrinterIndex := cbPrinters.ItemIndex;
  Memo1.lines.add('Huidige printer: '+ Printer.Printers[Printer.PrinterIndex])
end;


function TForm1.GetCurrentPrinterHandle: THandle;
const Defaults: TPrinterDefaults = (pDatatype: nil; pDevMode: nil; DesiredAccess: PRINTER_ACCESS_USE or PRINTER_ACCESS_ADMINISTER);
var Device, Driver, Port: array[0..255] of char;
    hDeviceMode: THandle;
begin
  Printer.GetPrinter(Device, Driver, Port, hDeviceMode);
  if not OpenPrinter(@Device, Result, @Defaults) then RaiseLastOSError
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


procedure TForm1.KillJobsOnCurrentPrinter;
var hPrinter: THandle;
begin
  hPrinter:= GetCurrentPrinterHandle;
  try
    if not WinSpool.SetPrinter(hPrinter, 0, nil, PRINTER_CONTROL_PURGE) then RaiseLastOSError;
  finally
    ClosePrinter(hPrinter)
  end;
end;


procedure TForm1.waitChange;
var hPrinter: THandle;
begin
  hPrinter:= GetCurrentPrinterHandle;
  try
//PRINTER_CHANGE_SET_JOB
//PRINTER_CHANGE_ADD_JOB
//PRINTER_CHANGE_WRITE_JOB
//PRINTER_CHANGE_JOB
    if WaitForPrinterChange(hPrinter, PRINTER_CHANGE_JOB)<>0 then begin
      Application.ProcessMessages;
      Memo1.lines.add('EVENT: Printer Job Change JOB');
      bPrintJobsClick(self);
    end;
  finally
    ClosePrinter(hPrinter)
  end;
(*
HANDLE chgObject;
DWORD *pdwChange;
BOOL fcnreturn;
chgObject = FindFirstPrinterChangeNotification( hPrinter, PRINTER_CHANGE_JOB, 0, NULL);
WaitForSingleObject(chgObject, INFINTE);
fcnreturn = FindNextPrinterChangeNotification(chgObject, pdwChange, NULL, NULL);
if (fcnreturn) {
     // check value of *pdwChange and deal with the indicated change
     }
*)
end;


procedure TForm1.ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
begin
//  waitChange
end;


procedure TForm1.WM_SpoolerStatus(var Msg : TWMSPOOLERSTATUS);
begin
  Memo1.lines.add(IntToStr(msg.JobsLeft) + ' Jobs currenly in spooler');
  msg.Result := 0;
end;


function TForm1.ShowPChar(p: PChar): PChar;
begin
  if not Assigned(p) then Result := 'Nil'
                     else Result := p;
end;




function TForm1.SpoolFile(const FileName: string) : Integer;
var Buffer: record
      JobInfo: record // ADDJOB_INFO_1
        Path: PCHAR;
        JobID: DWORD;
      end;
      PathBuffer: array[0..255] of char;
    end;
    SizeNeeded: DWORD;
    hPrinter: THandle;
begin
  Result := 2;  //file not found
  if not FileExists(FileName) then exit;
  hPrinter:= GetCurrentPrinterHandle;
  try
    if AddJob(hPrinter, 1, @Buffer, SizeOf(Buffer), SizeNeeded) then
      if CopyFile(PChar(FileName), Buffer.JobInfo.Path, true) then
        if ScheduleJob(hPrinter, Buffer.JobInfo.JobID) then
          Result := 0
        else
          Result := GetLastError;
  finally
    ClosePrinter(hPrinter);
  end;
end;

procedure TForm1.bPrintPRNClick(Sender: TObject);
begin
  // de aangegeven file direct in de printer-buffer plaatsen
  if SpoolFile(ePRN.Text)<>0 then ShowMessage('De .PRN file is NIET in de printer-wachtrij geplaatst !');
end;


procedure TForm1.bPrintJobsClick(Sender: TObject);
type TJobs  = array [0..1000] of JOB_INFO_1;
     PJobs = ^TJobs;
var hPrinter: THandle;
    bytesNeeded, numJobs, i: Cardinal;
    pJ: PJobs;
begin
  hPrinter := GetCurrentPrinterHandle;
  try
    EnumJobs(hPrinter, 0, 1000, 1, nil, 0, bytesNeeded, numJobs);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen print-opdrachten in de wachtrij')
    else begin
      pJ := AllocMem(bytesNeeded);
      try
        if not EnumJobs(hPrinter, 0, 1000, 1, pJ, bytesNeeded, bytesNeeded, numJobs) then RaiseLastOSError;
        for i:=0 to Pred(numJobs) do
          memo1.Lines.Add(Format('Printer: %s,   Doc: %s,   User: %s,  Status: (%d): %s',
            [ShowPChar(pJ^[i].pPrinterName), ShowPChar(pJ^[i].pDocument), ShowPChar(pJ^[i].pUserName),
             pJ^[i].Status, ShowPChar(pJ^[i].pStatus)]));
      finally
        FreeMem(pJ);
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;


procedure TForm1.bMonitorClick(Sender: TObject);
type TMonitors = array[0..1000] of TMonitorInfo1A;
     PMonitors = ^TMonitors;
var hPrinter: THandle;
    pM : PMonitors;
    bytesNeeded, numMonitors, i : cardinal;
    s : PChar;
begin
  hPrinter := GetCurrentPrinterHandle;
  try
    s := PChar(Printer.Printers[Printer.PrinterIndex]);
    EnumMonitors(s, 1, nil, 0, bytesNeeded, numMonitors);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen monitors voor de huidige printer')
    else begin
      pM := AllocMem(bytesNeeded);
      try
        if not EnumMonitors(s, 1, pM, bytesNeeded, bytesNeeded, numMonitors) then RaiseLastOSError;
        for i := 0 to Pred(numMonitors) do Memo1.Lines.add(ShowPChar(pM^[i].pName));
      finally
        FreeMem(pM);
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;


procedure TForm1.bPrintProcessorsClick(Sender: TObject);
type TProcs  = array[0..1000] of PRINTPROCESSOR_INFO_1;
     PProcs = ^TProcs;
     TProcsDir = array[0..1000] of char;
var hPrinter: THandle;
    bytesNeeded, numProcs, i: Cardinal;
    pP: PProcs;
    PD: TProcsDir;
begin
  hPrinter := GetCurrentPrinterHandle;
  try
    EnumPrintProcessors(getServerName(Printer.PrinterIndex), PChar(''), 1, pP, 0, bytesNeeded, numProcs);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen print-processors voor de huidige printer')
    else begin
      pP := AllocMem(bytesNeeded);
      try
        if not EnumPrintProcessors(getServerName(Printer.PrinterIndex), PChar(''), 1, pP, bytesNeeded, bytesNeeded, numProcs) then RaiseLastOSError;
        for i:=0 to Pred(numProcs) do begin
          memo1.Lines.Add(Format('Print-Processor: %s', [ShowPChar(pP^[i].pName)]));
          // de print-processor directory opvragen
          if GetPrintProcessorDirectory(getServerName(Printer.PrinterIndex), '', 1, @PD, SizeOf(TProcsDir), bytesNeeded) then memo1.lines.add('Print-Processor-Dir: '+ pD);
        end;
      finally
        FreeMem(pP);
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;


procedure TForm1.bDriverClick(Sender: TObject);
type TDrivers = array[0..1000] of DRIVER_INFO_1;
     PDrivers = ^TDrivers;
var hPrinter: THandle;
    s: PAnsiChar;
    pd: PDrivers;
    bytesNeeded, numDrivers, i: Cardinal;
begin
  hPrinter := GetCurrentPrinterHandle;
  s := PChar(Printer.Printers[Printer.PrinterIndex]);
  try
    EnumPrinterDrivers(s, PChar(''), 1, pd, 0, bytesNeeded, NumDrivers);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen printer-drivers voor de huidige printer')
    else begin
      pd := AllocMem(bytesNeeded);
      try
        if not EnumPrinterDrivers(s, PChar(''), 1, pd, bytesNeeded, bytesNeeded, NumDrivers) then RaiseLastOSError;
        for i:=0 to Pred(NumDrivers) do begin
          memo1.Lines.Add(Format('Printer-Driver: %s', [ShowPChar(pd^[i].pName)]));
        end;
      finally
        FreeMem(pd);
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;


procedure TForm1.bPortsClick(Sender: TObject);
type TPorts = array[0..1000] of TPortInfo1;
     PPorts = ^TPorts;
var hPrinter: THandle;
    s: PAnsiChar;
    pp: PPorts;
    bytesNeeded, numPorts, i: Cardinal;
begin
  hPrinter := GetCurrentPrinterHandle;
  s := PChar(Printer.Printers[Printer.PrinterIndex]);
  try
    EnumPorts(s, 1, pp, 0, bytesNeeded, numPorts);
    if bytesNeeded = 0 then
      memo1.Lines.Add('Geen printer-ports voor de huidige printer')
    else begin
      pp := AllocMem(bytesNeeded);
      try
        if not EnumPorts(s, 1, pp, bytesNeeded, bytesNeeded, numPorts) then RaiseLastOSError;
        for i:=0 to Pred(numPorts) do begin
          memo1.Lines.Add(Format('Printer-Port: %s', [ShowPChar(pp^[i].pName)]));
        end;
      finally
        FreeMem(pp);
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;


procedure TForm1.Button1Click(Sender: TObject);
begin
//  memo1.lines.add(IPFromComputername('\\UDSBSDEV03'));
end;






procedure TForm1.Button2Click(Sender: TObject);
begin
  //
end;

end.
