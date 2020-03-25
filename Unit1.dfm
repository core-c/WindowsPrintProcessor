object Form1: TForm1
  Left = 146
  Top = 116
  BorderStyle = bsSingle
  Caption = 'Print Systeem'
  ClientHeight = 425
  ClientWidth = 946
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object lJobID: TLabel
    Left = 8
    Top = 280
    Width = 49
    Height = 25
    Alignment = taCenter
    AutoSize = False
    Color = clTeal
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWhite
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = []
    ParentColor = False
    ParentFont = False
  end
  object Label2: TLabel
    Left = 8
    Top = 16
    Width = 77
    Height = 13
    Caption = 'Huidige printer : '
  end
  object Memo1: TMemo
    Left = 8
    Top = 40
    Width = 393
    Height = 65
    Color = clBtnFace
    ReadOnly = True
    TabOrder = 0
  end
  object bPrintJobs: TButton
    Left = 824
    Top = 280
    Width = 113
    Height = 25
    Caption = 'Ververs Wachtrij'
    TabOrder = 1
    OnClick = bPrintJobsClick
  end
  object bMonitor: TButton
    Left = 824
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
  object bPrintProcessors: TButton
    Left = 824
    Top = 8
    Width = 113
    Height = 25
    Caption = 'PrintProcessors'
    TabOrder = 4
    OnClick = bPrintProcessorsClick
  end
  object bPauseJob: TButton
    Left = 64
    Top = 280
    Width = 75
    Height = 25
    Caption = 'Pauzeren'
    Enabled = False
    TabOrder = 5
    OnClick = bPauseJobClick
  end
  object bResumeJob: TButton
    Left = 144
    Top = 280
    Width = 75
    Height = 25
    Caption = 'Hervatten'
    Enabled = False
    TabOrder = 6
    OnClick = bResumeJobClick
  end
  object bCancelJob: TButton
    Left = 224
    Top = 280
    Width = 75
    Height = 25
    Caption = 'Annuleren'
    Enabled = False
    TabOrder = 7
    OnClick = bCancelJobClick
  end
  object lvPrintJobs: TListView
    Left = 8
    Top = 112
    Width = 929
    Height = 161
    Columns = <
      item
        Caption = 'JobID'
        MinWidth = 100
      end
      item
        Caption = 'Eigenaar'
        MinWidth = 75
        Width = 75
      end
      item
        Caption = 'Pagina'#39's'
        MinWidth = 55
        Width = 55
      end
      item
        Caption = 'Document'
        MinWidth = 170
        Width = 170
      end
      item
        Caption = 'Datum/Tijd'
        Width = 120
      end
      item
        Caption = 'Status'
        MinWidth = 278
        Width = 278
      end
      item
        Caption = 'Computer'
        Width = 100
      end
      item
        Caption = 'Grootte'
        Width = 75
      end>
    HideSelection = False
    RowSelect = True
    TabOrder = 8
    ViewStyle = vsReport
    OnSelectItem = lvPrintJobsSelectItem
  end
  object bCancelJobs: TButton
    Left = 304
    Top = 280
    Width = 145
    Height = 25
    Caption = 'Alle Opdrachten Annuleren'
    TabOrder = 9
    OnClick = bCancelJobsClick
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 336
    Width = 601
    Height = 81
    Caption = ' Afdrukken .PRN Bestanden '
    TabOrder = 10
    object Label1: TLabel
      Left = 24
      Top = 48
      Width = 30
      Height = 13
      Caption = 'Printer'
    end
    object Label3: TLabel
      Left = 16
      Top = 24
      Width = 39
      Height = 13
      Caption = 'Bestand'
    end
    object bPrintPRN: TButton
      Left = 328
      Top = 44
      Width = 113
      Height = 25
      Caption = 'Print .PRN Bestand'
      TabOrder = 0
      OnClick = bPrintPRNClick
    end
    object ePRN: TEdit
      Left = 64
      Top = 20
      Width = 529
      Height = 21
      TabOrder = 1
      Text = 'c:\test.prn'
    end
    object cbPRNPrinter: TComboBox
      Left = 64
      Top = 44
      Width = 257
      Height = 21
      ItemHeight = 13
      TabOrder = 2
    end
  end
  object Memo2: TMemo
    Left = 440
    Top = 8
    Width = 305
    Height = 81
    ScrollBars = ssVertical
    TabOrder = 11
  end
end
