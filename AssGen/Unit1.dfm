object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = 'Ass Maker'
  ClientHeight = 162
  ClientWidth = 267
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 42
    Height = 13
    Caption = 'Input Dir'
  end
  object Label2: TLabel
    Left = 16
    Top = 88
    Width = 34
    Height = 13
    Caption = 'Output'
  end
  object InputDir: TEdit
    Left = 56
    Top = 8
    Width = 121
    Height = 21
    Enabled = False
    TabOrder = 0
  end
  object Button1: TButton
    Left = 184
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Select'
    TabOrder = 1
    OnClick = Button1Click
  end
  object opFile: TRadioButton
    Left = 56
    Top = 40
    Width = 41
    Height = 17
    Caption = 'File'
    TabOrder = 2
  end
  object RadioButton1: TRadioButton
    Left = 128
    Top = 40
    Width = 41
    Height = 17
    Caption = 'GRF'
    TabOrder = 3
  end
  object OutFile: TEdit
    Left = 56
    Top = 80
    Width = 121
    Height = 21
    Enabled = False
    TabOrder = 4
  end
  object Button2: TButton
    Left = 184
    Top = 80
    Width = 75
    Height = 25
    Caption = 'Select'
    TabOrder = 5
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 96
    Top = 112
    Width = 75
    Height = 25
    Caption = 'Generate'
    TabOrder = 6
    OnClick = Button3Click
  end
  object Progress: TProgressBar
    Left = 0
    Top = 144
    Width = 265
    Height = 16
    Smooth = True
    TabOrder = 7
  end
  object Button4: TButton
    Left = 184
    Top = 112
    Width = 75
    Height = 25
    Caption = 'Button4'
    TabOrder = 8
    OnClick = Button4Click
  end
  object SaveDialog: TSaveDialog
    DefaultExt = '.ass'
    Filter = 'Ass|*.ass'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 8
    Top = 24
  end
end
