object Form1: TForm1
  Left = 266
  Top = 114
  BorderStyle = bsSingle
  Caption = 'Form1'
  ClientHeight = 466
  ClientWidth = 665
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 16
    Width = 68
    Height = 13
    Caption = 'Huidige printer'
  end
  object Memo1: TMemo
    Left = 8
    Top = 104
    Width = 649
    Height = 129
    TabOrder = 0
  end
  object bPrintJobs: TButton
    Left = 464
    Top = 40
    Width = 113
    Height = 25
    Caption = 'Printer Wachtrij'
    TabOrder = 1
    OnClick = bPrintJobsClick
  end
  object bMonitor: TButton
    Left = 232
    Top = 40
    Width = 113
    Height = 25
    Caption = 'Monitors'
    TabOrder = 2
    OnClick = bMonitorClick
  end
  object cbPrinters: TComboBox
    Left = 88
    Top = 8
    Width = 313
    Height = 21
    ItemHeight = 13
    TabOrder = 3
    OnChange = cbPrintersChange
  end
  object bPrintPRN: TButton
    Left = 8
    Top = 72
    Width = 113
    Height = 25
    Caption = 'Print .PRN Bestand'
    TabOrder = 4
    OnClick = bPrintPRNClick
  end
  object ePRN: TEdit
    Left = 128
    Top = 72
    Width = 449
    Height = 21
    TabOrder = 5
    Text = 'c:\test.prn'
  end
  object bPrintProcessors: TButton
    Left = 344
    Top = 40
    Width = 113
    Height = 25
    Caption = 'PrintProcessors'
    TabOrder = 6
    OnClick = bPrintProcessorsClick
  end
  object Button1: TButton
    Left = 584
    Top = 72
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 7
    OnClick = Button1Click
  end
  object bDriver: TButton
    Left = 120
    Top = 40
    Width = 113
    Height = 25
    Caption = 'Drivers'
    TabOrder = 8
    OnClick = bDriverClick
  end
  object bPorts: TButton
    Left = 8
    Top = 40
    Width = 113
    Height = 25
    Caption = 'Ports'
    TabOrder = 9
    OnClick = bPortsClick
  end
  object Button2: TButton
    Left = 80
    Top = 312
    Width = 75
    Height = 25
    Caption = 'Button2'
    TabOrder = 10
    OnClick = Button2Click
  end
  object ApplicationEvents1: TApplicationEvents
    OnIdle = ApplicationEvents1Idle
    Left = 408
    Top = 8
  end
end
