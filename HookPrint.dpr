library HookPrint;
{$IMAGEBASE $5a000000}
uses Windows, Messages, madCodeHook, madStrings, SysUtils;
{$E .dll}

var CreateDCANext : function (driver, device, output: pchar; dm: PDeviceModeA) : dword; stdcall;
    CreateDCWNext : function (driver, device, output: pwidechar; dm: PDeviceModeW) : dword; stdcall;
    StartDocANext : function (dc: dword; const di: TDocInfoA) : integer; stdcall;
    StartDocWNext : function (dc: dword; const di: TDocInfoW) : integer; stdcall;
    EndDocNext    : function (dc: dword) : integer; stdcall;
    StartPageNext : function (dc: dword) : integer; stdcall;
    EndPageNext   : function (dc: dword) : integer; stdcall;
    AbortDocNext  : function (dc: dword) : integer; stdcall;

procedure Notify(api: string; deviceA: pchar; deviceW: pwidechar;
                 dc: dword; dia: PDocInfoA; diw: PDocInfoW; job: integer; result: boolean);
// this function composes all the strings and sends them to our log window

  function AwToStr(ansi: pchar; wide: pwidechar) : string;
  // return the string which is contained in either "ansi" or "wide"
  begin
    if wide <> nil then begin
      ansi := PChar(WideCharToString(wide));
//      ansi := WideToAnsi(wide);
      result := ansi;
      LocalFree(dword(ansi));
    end else
      result := ansi;
  end;
  
type
  TLogAction = record
    process : array [0..MAX_PATH] of char;
    api     : array [0..MAX_PATH] of char;
    params  : array [0..MAX_PATH] of char;
    result  : array [0..MAX_PATH] of char;
  end;
var la     : TLogAction;
    s1     : string;
    window : dword;
    cds    : TCopyDataStruct;
    c1     : dword;
begin
//@@  if AmUsingInputDesktop then begin
    // fill the "process" and "api" strings, the format is independent of the API
    GetModuleFileName(0, la.process, MAX_PATH);
    lstrcpy(la.api, pchar(api));
    if (deviceA <> nil) or (deviceW <> nil) then begin
      // this is the CreateDCA/W API
      s1 := AwToStr(deviceA, deviceW);
      if lstrcmpA('\\.\DISPLAY', pchar(Copy(s1, 1, 11))) = 0 then
        // no, we don't want to display dcs!
        exit;
      // we output one parameter, namely the printer name
      lstrcpy(la.params, pchar('printer: "' + s1 + '"'));
      // the result is either a valid dc handle or a failure indicator
      if dc <> 0 then
           lstrcpy(la.result, pchar('dc: ' + IntToHexEx(dc)))
      else lstrcpy(la.result, 'error');
    end else begin
        // all other APIs have a "dc" paramter, so we output it first
        s1 := 'dc: ' + IntToHexEx(dc);
        if (dia <> nil) or (diw <> nil) then begin
          // this is the StartDocA/W API, it has an additional "doc" parameter
          if dia <> nil then begin
            // ansi version
            if dia^.lpszDocName <> nil then
              s1 := s1 + '; doc: "' + dia^.lpszDocName + '"';
            if dia^.lpszOutput <> nil then
              s1 := s1 + '; output: "' + dia^.lpszOutput + '"';
          end else begin
            // wide version
            if diw^.lpszDocName <> nil then
              s1 := s1 + '; doc: "' + AwToStr(nil, diw^.lpszDocName) + '"';
            if diw^.lpszOutput <> nil then
              s1 := s1 + '; file: "' + AwToStr(nil, diw^.lpszOutput) + '"';
          end;
          // the result is either a valid job identifier or a failure indicator
          if job > 0 then
               lstrcpy(la.result, pchar('job: ' + IntToHexEx(job)))
          else lstrcpy(la.result, 'error');
        end else
          // all the other ideas have only a boolean result
          if result then
               lstrcpy(la.result, 'success')
          else lstrcpy(la.result, 'error'  );
        lstrcpy(la.params, pchar(s1));
//@@    end;

    // now send the composed strings to our log window
    window := FindWindow('TFLogPrintingActions', 'log printing actions');
    if window <> 0 then begin
      cds.dwData := window + 777;
      cds.cbData := sizeOf(la);
      cds.lpData := @la;
      SendMessageTimeOut(window, WM_COPYDATA, 0, integer(@cds), SMTO_ABORTIFHUNG, 2000, c1);
    end;

  end;
end;

function CreateDCACallback(driver, device, output: pchar; dm: PDeviceModeA) : dword; stdcall;
begin
  result := CreateDCANext(driver, device, output, dm);
  // we log this call only if it is a printer DC creation
  if (device <> nil) and (not IsBadReadPtr(device, 1)) and (device^ <> #0) then
    Notify('CreateDCA', device, nil, result, nil, nil, 0, false);
end;

function CreateDCWCallback(driver, device, output: pwidechar; dm: PDeviceModeW) : dword; stdcall;
begin
  result := CreateDCWNext(driver, device, output, dm);
  // we log this call only if it is a printer DC creation
  if (device <> nil) and (not IsBadReadPtr(device, 2)) and (device^ <> #0) then
    Notify('CreateDCW', nil, device, result, nil, nil, 0, false);
end;

function StartDocACallback(dc: dword; const di: TDocInfoA) : integer; stdcall;
begin
  result := StartDocANext(dc, di);
  Notify('StartDocA', nil, nil, dc, @di, nil, result, false);
end;

function StartDocWCallback(dc: dword; const di: TDocInfoW) : integer; stdcall;
//@var vDI : TDocInfoW;
//@    s : PChar;
begin
  // printen naar een bestand !!
//@  s := PChar('c:\'+ PChar(di.lpszDocName) +'.prn');
//@  vDI := di;
//@  vDI.lpszOutput := @s;
//@@  di.lpszOutput := PChar('c:\'+ PChar(di.lpszDocName) +'.prn');
//@  result := StartDocWNext(dc, vDI);
//@  Notify('StartDocW', nil, nil, dc, nil, @vDI, result, false);


//@@  result := StartDocWNext(dc, di);
//@@  Notify(PChar(di.lpszDocName), nil, nil, dc, nil, @di, result, false);


//--------------------- orgineel-------------------------------
  result := StartDocWNext(dc, di);
  Notify('StartDocW', nil, nil, dc, nil, @di, result, false);
end;

function EndDocCallback(dc: dword) : integer; stdcall;
begin
  result := EndDocNext(dc);
  Notify('EndDoc', nil, nil, dc, nil, nil, 0, result > 0);
end;

function StartPageCallback(dc: dword) : integer; stdcall;
begin
  result := StartPageNext(dc);
  Notify('StartPage', nil, nil, dc, nil, nil, 0, result > 0);
end;

function EndPageCallback(dc: dword) : integer; stdcall;
begin
  result := EndPageNext(dc);
  Notify('EndPage', nil, nil, dc, nil, nil, 0, result > 0);
end;

function AbortDocCallback(dc: dword) : integer; stdcall;
begin
  result := AbortDocNext(dc);
  Notify('AbortDoc', nil, nil, dc, nil, nil, 0, result > 0);
end;



(*
function AddJobCallBack(hPrinter: THandle; Level: DWORD; pData: Pointer; cbBuf: DWORD; var pcbNeeded: DWORD): BOOL; stdcall;
begin
  Result := AddJobNext(hPrinter, Level, pData, cbBuf, pcbNeeded);
  if (hPrinter<>0) then
    Notify('AddJob', nil, nil, 0, nil, nil, integer(hPrinter), result);
end;
*)


begin
  // collecting hooks can improve the hook installation performance in win9x
  CollectHooks;
  HookCode(@CreateDCA, @CreateDCACallback, @CreateDCANext);
  HookCode(@CreateDCW, @CreateDCWCallback, @CreateDCWNext);
  HookCode(@StartDocA, @StartDocACallback, @StartDocANext);
  HookCode(@StartDocW, @StartDocWCallback, @StartDocWNext);
  HookCode(@EndDoc,    @EndDocCallback,    @EndDocNext   );
  HookCode(@StartPage, @StartPageCallback, @StartPageNext);
  HookCode(@EndPage,   @EndPageCallback,   @EndPageNext  );
  HookCode(@AbortDoc,  @AbortDocCallback,  @AbortDocNext );
(*
  HookCode(@AddJob,    @AddJobCallback,    @AddJobNext   );
*)
  FlushHooks;
end.
