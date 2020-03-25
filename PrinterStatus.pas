unit PrinterStatus;
interface
uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Printers, WinSpool;


const
  imaxPrintJobs = 10000;

type
  EPrintError = class(Exception);

  TPrinterState = (psPAUSED, psERROR, psDELETING, psSPOOLING,
                   psPRINTING, psOFFLINE, psPAPEROUT, psPRINTED, psDELETED,
                   psBLOCKED_DEVQ, psUSER_INTERVENTION, psRESTART, psUNKNOWN, psOK);

  TPrinterStates = set of TPrinterState;

  TArrayJobInfo2 = array[0..iMaxPrintJobs] of TJobInfo2;

  { Dit component kan worden gebruikt om de status van een (remote) printer
    op te vragen. Met SpoolerReady kan worden opgevraagd of de spooler
    beschikbaar is. Als er tijdens de verdere controle iets mis gaan wordt een
    EPrintError geraised. Kontroleer voor het printen altijd of de spooler
    te benaderen is. }
  TPrinterStatus = class(TComponent)
  private
    FDefaultPrinter: boolean;
    FSpoolerErrorID: integer;
    FSpoolerErrorStr: string;
    FErrorStart: integer;
    FstrPrinterName: string;
  	FhPrinter      : THAndle;
	  FpPrinterInfo2 : ^TPrinterInfo2;
	  FpJobStorage   : ^TArrayJobInfo2;
	  FNrOfJobs      : DWORD;
    FErrorStates: TPrinterStates;
    function StorePrinterName: boolean;
    function GetSpoolerReady: boolean;
    function GetJobs: Boolean;
    function GetJobStatus(Index: integer): TPrinterStates;
    function GetStatusDesc(Index: integer): string;
    function QueueStatus: DWORD;
    procedure SetPrinterName(Value: string);
    function GetJobCount: integer;
    procedure SetDefaultPrinter(Value: boolean);
    function GetJobInfo(Index: integer): TJobInfo2;
  protected
  public
    { Aantal jobs voor geselekteerde printer }
    property JobCount: integer read GetJobCount;
    { Status voor een bepaalde job. Als Index buiten de range is wordt een
      lege set gegeven

        TPrinterState = (psPAUSED, psERROR, psDELETING, psSPOOLING,
                         psPRINTING, psOFFLINE, psPAPEROUT, psPRINTED, psDELETED,
                         psBLOCKED_DEVQ, psUSER_INTERVENTION, psRESTART,
                         psUNKNOWN, psOK)

        TPrinterStates = set of TPrinterState }
    property JobStatus[Index: Integer]: TPrinterStates read GetJobStatus;
    { Omschrijving van de status van een bepaalde job. Als meerdere statussen
      gelden voor de job worden deze achter elkaar geplakt, gescheiden door
      een spatie }
    property StatusDesc[Index: Integer]: string read GetStatusDesc;
    { Geeft aan of de spooler klaar is. Er wordt gekeken naar de spoolerstatus
      en of de jobs bereikbaar zijn. Als dit niet het geval is zal meestal het
      betreffende station niet aan staan. Met SpoolerErrorStr en SpoolerErrorID
      kan worden opgevraagd wat de fout is. }
    property SpoolerReady: boolean read GetSpoolerReady;
    { Omschrijving van de laatst opgetreden fout }
    property SpoolerErrorStr: string read FSpoolerErrorStr;
    { ID van de laatst opgetreden fout }
    property SpoolerErrorID: integer read FSpoolerErrorID;

    { Geeft een jobinfo van een printjob. Het type TJobInfo2 is gedefinieerd in
      de Delphi unit WinSpool.pas.

        TJobInfo2W = record
         JobId: DWORD;
         pPrinterName: PWideChar;
         pMachineName: PWideChar;
         pUserName: PWideChar;
         pDocument: PWideChar;
         pNotifyName: PWideChar;
         pDatatype: PWideChar;
         pPrintProcessor: PWideChar;
         pParameters: PWideChar;
         pDriverName: PWideChar;
         pDevMode: PDeviceModeW;
         pStatus: PWideChar;
         pSecurityDescriptor: PSECURITY_DESCRIPTOR;
         Status: DWORD;
         Priority: DWORD;
         Position: DWORD;
         StartTime: DWORD;
         UntilTime: DWORD;
         TotalPages: DWORD;
         Size: DWORD;
         Submitted: TSystemTime;   // Time the job was spooled
         Time: DWORD;              // How many seconds the job has been printing
         PagesPrinted: DWORD;
        end;
        TJobInfo2 = TJobInfo2A; }
    property JobInfo[Index: Integer]: TJobInfo2 read GetJobInfo;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function FirstJobInError: Integer;
    function NextJobInError: Integer;
    function FindJob(Title: string): Integer;

  published
    { Printer waarop moet worden gekontroleerd, dit is de printernaam zoals deze
      in My Computer/Printers staat. Als Printernaam leeg wordt gelaten wordt
      DefaultPrinter op true gezet }
    property PrinterName: string
      read FstrPrinterName write SetPrinterName stored StorePrinterName;
    { Set van statussen die als fout worden gezien. FirstJobInError en
      NextJobInError gebruiken deze property om te kijken of een job fout is

        TPrinterState = (psPAUSED, psERROR, psDELETING, psSPOOLING,
                         psPRINTING, psOFFLINE, psPAPEROUT, psPRINTED, psDELETED,
                         psBLOCKED_DEVQ, psUSER_INTERVENTION, psRESTART,
                         psUNKNOWN, psOK)

        TPrinterStates = set of TPrinterState }
    property ErrorStates: TPrinterStates
      read FErrorStates write FErrorStates default [psERROR, psOFFLINE];
    { Bepaalt of altijd de default printer wordt gebruikt of de printer zoals
      deze in PrinterName is opgegeven. Als deze property aan wordt gezet wordt
      de PrinterName meteen op de default printer gezet }
    property DefaultPrinter: boolean
      read FDefaultPrinter write SetDefaultPrinter default true;
  end;

procedure Register;




implementation


procedure Register;
begin
  RegisterComponents('HCore', [TPrinterStatus]);
end;


{ Default errorstates worden gezet en printername wordt op default printer gezet }
constructor TPrinterStatus.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSpoolerErrorStr := '';
  FpPrinterInfo2 := nil;
  FpJobStorage := nil;
  FErrorStates := [psERROR, psOFFLINE];
  FDefaultPrinter := true;
  SetPrinterName('');
end;


destructor TPrinterStatus.Destroy;
begin
  if FpPrinterInfo2 <> nil then dispose(FpPrinterInfo2);
	if FpJobStorage <> nil then dispose(FpJobStorage);
  inherited Destroy;
end;


function TPrinterStatus.GetJobCount: integer;
begin
  Result := -1;
  if QueueStatus = 0 then Result := FNrOfJobs;
end;


{ Vraagt de status van de queue op en vult FNrOfJobs }
function TPrinterStatus.QueueStatus: DWORD;
var cbBuf : DWORD;
    pcbBuf : pointer;
    Needed : DWORD;
    pcbNeeded : LPDWORD;
begin
  pcbBuf := @cbBuf;
  if not GetPrinter(FhPrinter,2,Nil,0,pcbBuf) then
    if GetLastError <> ERROR_INSUFFICIENT_BUFFER then begin
      FSpoolerErrorStr := Name + ': GetPrinterQueueStatus Getprinter1 fout: ' + IntToStr(GetLastError);
      FSpoolerErrorID := GetLastError;
      raise EPrintError.Create(FSpoolerErrorStr);
    end;
  if FpPrinterInfo2 <> nil then dispose(FpPrinterInfo2);
  GetMem(FpPrinterInfo2,cbBuf);
  fillChar(FpPrinterInfo2^,cbBuf,0);
  pcbNeeded := @Needed;
  if not GetPrinter(FhPrinter,2,FpPrinterInfo2,cbBuf,pcbNeeded) then begin
		FSpoolerErrorStr := Name + ': GetPrinterQueueStatus Getprinter2 fout: ' + IntToStr(GetLastError);
		FSpoolerErrorID := GetLastError;
		raise EPrintError.Create(FSpoolerErrorStr);
  end;
  Result := FpPrinterInfo2^.status;
  FNrOfJobs := FpPrinterInfo2^.cJobs;
end;


procedure TPrinterStatus.SetPrinterName(Value: string);
begin
  { ALs property niet verandert ook niets uitvoeren. Als een lege waarde wordt
    meegegeven kan dit de initialisatie zijn, deze moet dus altijd worden
    uitgevoerd }
  if (Value <> FstrPrinterName) or (Value = '') then begin
    FErrorStart := -1;
    { Als de waarde op leeg wordt gezet wordt de default printer gezet. Deze
      wordt (design-time) niet opgeslagen omdat ook run-time dan de default
      printer moet worden geselekteerd }
    if Trim(Value) = '' then
      with Printer do begin
        FDefaultPrinter := true;
        Value := Printers[PrinterIndex];
      end else
        FDefaultPrinter := false;
    if not Openprinter(PChar(Value), FhPrinter, nil) then begin
  		FSpoolerErrorStr := 'TPrtStat.Create Openprinter fout: ' + IntToStr(GetLastError);
  		FSpoolerErrorID := GetLastError;
  		raise EPrintError.Create(FSpoolerErrorStr);
    end;
    FstrPrinterName := Value;
  end;
end;


{ Als Defaultprinter aan staat moet de printernaam niet worden opgeslagen }
function TPrinterStatus.StorePrinterName: boolean;
begin
  Result := not FDefaultPrinter;
end;


function TPrinterStatus.GetJobStatus(Index: integer): TPrinterStates;
var Status: DWORD;
begin
  result := [];
  if (Index >= JobCount) or (Index < 0) then Exit;
  if not GetJobs then Exit;
  Status := FpJobStorage^[Index].status;
  if Status = 0 then
    Result := [psOK]
  else begin
    if (JOB_STATUS_PAUSED and Status) = JOB_STATUS_PAUSED then Result := Result + [psPAUSED];
    if (JOB_STATUS_ERROR and Status) = JOB_STATUS_ERROR then Result := Result + [psERROR];
    if (JOB_STATUS_DELETING and Status) = JOB_STATUS_DELETING then Result := Result + [psDELETING];
    if (JOB_STATUS_SPOOLING and Status) = JOB_STATUS_SPOOLING then Result := Result + [psSPOOLING];
    if (JOB_STATUS_PRINTING and Status) = JOB_STATUS_PRINTING then Result := Result + [psPRINTING];
    if (JOB_STATUS_OFFLINE and Status) = JOB_STATUS_OFFLINE then Result := Result + [psOFFLINE];
    if (JOB_STATUS_PAPEROUT and Status) = JOB_STATUS_PAPEROUT then Result := Result + [psPAPEROUT];
    if (JOB_STATUS_PRINTED and Status) = JOB_STATUS_PRINTED then Result := Result + [psPRINTED];
    if (JOB_STATUS_DELETED and Status) = JOB_STATUS_DELETED then Result := Result + [psDELETED];
    if (JOB_STATUS_BLOCKED_DEVQ and Status) = JOB_STATUS_BLOCKED_DEVQ then Result := Result + [psBLOCKED_DEVQ];
    if (JOB_STATUS_USER_INTERVENTION and Status) = JOB_STATUS_USER_INTERVENTION then Result := Result + [psUSER_INTERVENTION];
    if Result = [] then Result := [psUNKNOWN];
  end;
end;


function TPrinterStatus.GetJobs: Boolean;
var cbBuf : DWORD;
    Needed : DWORD;
begin
  GetJobs := false;
  if JobCount >= 0 then begin
    if not EnumJobs(FhPrinter,0,FpPrinterInfo2^.cJobs,2,FpJobStorage,0,cbBuf,Needed) then
      if GetLastError <> ERROR_INSUFFICIENT_BUFFER then begin
    		FSpoolerErrorStr := 'Fout bij bepalen JOB-buffer: ' + IntToStr(GetLastError);
    		FSpoolerErrorID := GetLastError;
    		raise EPrintError.Create(FSpoolerErrorStr);
      end;
    if FpJobStorage <> nil then dispose(FpJobStorage);
    GetMem(FpJobStorage,cbBuf);
    fillChar(FpJobStorage^,cbBuf,0);
    if not EnumJobs(FhPrinter,0,FpPrinterInfo2^.cJobs,2,FpJobStorage,cbBuf,Needed,cbBuf) then begin
			FSpoolerErrorStr := 'Fout bij EnumJobs: ' + IntToStr(GetLastError);
			FSpoolerErrorID := GetLastError;
			raise EPrintError.Create(FSpoolerErrorStr);
    end;
    GetJobs := true;
  end;
end;


function TPrinterStatus.GetStatusDesc(Index: Integer): string;
var Status: TPrinterStates;
begin
  Status := GetJobStatus(Index);
  Result := '';
	if (psPAUSED in Status) then Result := Result + ' PAUSED';
	if (psERROR in Status) then Result := Result + ' ERROR';
	if (psDELETING in Status) then Result := Result + ' DELETING';
	if (psSPOOLING in Status) then Result := Result + ' SPOOLING';
	if (psPRINTING in Status) then Result := Result + ' PRINTING';
	if (psOFFLINE in Status) then Result := Result + ' OFFLINE';
	if (psPAPEROUT in Status) then Result := Result + ' PAPEROUT';
	if (psPRINTED in Status) then Result := Result + ' PRINTED';
	if (psDELETED in Status) then Result := Result + ' DELETED';
	if (psBLOCKED_DEVQ in Status) then Result := Result + ' BLOCKED';
	if (psUSER_INTERVENTION in Status) then Result := Result + ' USERINTERVENTION';
end;


{ Geeft de index van de eerste job die in error staat. Gebruik deze functie om
  te kijken of er fouten zijn, zolang deze -1 retoureerd zijn er geen fouten.
  Als deze functie een jobnummer geeft met een fout kan met NextJobInError
  worden opgevraagd of er nog meer jobs met fouten zijn. De property
  ErrorStates bepaalt welke statussen als 'fout' worden gezien }
function TPrinterStatus.FirstJobInError: Integer;
begin
  FErrorStart := 0;
  Result := NextJobInError;
end;


{ Als FirstJobInError een jobnummer geeft met een fout kan met NextJobInError
  worden opgevraagd of er nog meer jobs met fouten zijn. De property
  ErrorStates bepaalt welke statussen als 'fout' worden gezien }
function TPrinterStatus.NextJobInError: Integer;
var i: Integer;
begin
  if FErrorStart = -1 then
    raise Exception.Create(Name + ': FirstJobInError not executed before NextJobInError');
  Result := -1;
  for i := FErrorStart to JobCount - 1 do
    if (GetJobStatus(i) * ErrorStates) <> [] then begin
      Result := i;
      Break;
    end;
  if Result = -1 then FErrorStart := JobCount+1
                 else FErrorStart := Result + 1;
end;


function TPrinterStatus.GetSpoolerReady: boolean;
begin
  FSpoolerErrorStr := '';
  try
    Result := (QueueStatus = 0) and (GetJobs);
  except
    on e: EPrintError do Result := false;
    on e: Exception do raise
  end;
end;


procedure TPrinterStatus.SetDefaultPrinter(Value: boolean);
begin
  if Value <> FDefaultPrinter then begin
    FDefaultPrinter := Value;
    if FDefaultPrinter then SetPrinterName('');
  end;
end;


function TPrinterStatus.GetJobInfo(Index: integer): TJobInfo2;
begin
  if (Index < 0) or (Index >= JobCount) then Exit;
  Result := FpJobStorage^[Index];
end;


{ Zoekt naar een job aan de hand van zijn title (pDocument) De index van de job
  in de queue wordt geretourneerd, als de job niet is gevonden wordt -1
  geretourneerd. Deze routine kan worden gebruikt om te kijken of een document
  daadwerkelijk in de queue is opgenomen.

       with Printer do
       begin
         Title := 'Testje';  <--------Altijd voor BeginDoc
         BeginDoc;
         Canvas.TextOut(0, 0, 'TestPrint');
         EndDoc;

         if mbPrinterStatus.FindJob(Title) = -1 then
           ShowMessage('OOPS!!');
       end;
}
function TPrinterStatus.FindJob(Title: string): Integer;
var i: Integer;
begin
  Result := -1;
  if GetJobs then
    for i := 0 to JobCount - 1 do
      if (JobInfo[i].pDocument <> '') and (JobInfo[i].pDocument = Title) then begin
        Result := i;
        Break;
      end;
end;


end.

