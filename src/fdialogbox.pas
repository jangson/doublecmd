{
    Double Commander
    -------------------------------------------------------------------------
    This unit contains realization of Dialog API functions.

    Copyright (C) 2008-2019 Alexander Koblov (alexx2000@mail.ru)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
}

unit fDialogBox;

{$mode objfpc}{$H+}
{$include calling.inc}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Types, Buttons, ExtCtrls, EditBtn, Extension, ComCtrls, DividerBevel;

type

  { TDialogBox }

  TDialogBox = class(TForm)
    DialogButton: TButton;
    DialogBitBtn: TBitBtn;
    DialogFileNameEdit: TFileNameEdit;
    DialogComboBox: TComboBox;
    DialogListBox: TListBox;
    DialogCheckBox: TCheckBox;
    DialogGroupBox: TGroupBox;
    DialogLabel: TLabel;
    DialogPanel: TPanel;
    DialogEdit: TEdit;
    DialogMemo: TMemo;
    DialogImage: TImage;
    DialogTabSheet: TTabSheet;
    DialogRadioGroup: TRadioGroup;
    DialogPageControl: TPageControl;
    DialogDividerBevel: TDividerBevel;
    // Dialog events
    procedure DialogBoxShow(Sender: TObject);
    // Button events
    procedure ButtonClick(Sender: TObject);
    procedure ButtonEnter(Sender: TObject);
    procedure ButtonExit(Sender: TObject);
    procedure ButtonKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ButtonKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    // ComboBox events
    procedure ComboBoxClick(Sender: TObject);
    procedure ComboBoxDblClick(Sender: TObject);
    procedure ComboBoxChange(Sender: TObject);
    procedure ComboBoxEnter(Sender: TObject);
    procedure ComboBoxExit(Sender: TObject);
    procedure ComboBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ComboBoxKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    // Edit events
    procedure EditClick(Sender: TObject);
    procedure EditDblClick(Sender: TObject);
    procedure EditChange(Sender: TObject);
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    // ListBox events
    procedure ListBoxClick(Sender: TObject);
    procedure ListBoxDblClick(Sender: TObject);
    procedure ListBoxSelectionChange(Sender: TObject; User: boolean);
    procedure ListBoxEnter(Sender: TObject);
    procedure ListBoxExit(Sender: TObject);
    procedure ListBoxKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListBoxKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    // CheckBox events
    procedure CheckBoxChange(Sender: TObject);
  private
    FDlgProc: TDlgProc;
    FResult: LongBool;
    FTranslator: TAbstractTranslator;
  protected
    procedure ShowDialogBox;
    procedure ProcessResource; override;
    function InitResourceComponent(Instance: TComponent; RootAncestor: TClass): Boolean;
  public
    constructor Create(DlgProc: TDlgProc); reintroduce;
    destructor Destroy; override;
  end; 

function InputBox(Caption, Prompt: PAnsiChar; MaskInput: LongBool; Value: PAnsiChar; ValueMaxLen: Integer): LongBool; dcpcall;
function MessageBox(Text, Caption: PAnsiChar; Flags: Longint): Integer; dcpcall;
function DialogBoxLFM(LFMData: Pointer; DataSize: LongWord; DlgProc: TDlgProc): LongBool; dcpcall;
function DialogBoxLRS(LRSData: Pointer; DataSize: LongWord; DlgProc: TDlgProc): LongBool; dcpcall;
function DialogBoxLFMFile(lfmFileName: PAnsiChar; DlgProc: TDlgProc): LongBool; dcpcall;
function SendDlgMsg(pDlg: PtrUInt; DlgItemName: PAnsiChar; Msg, wParam, lParam: PtrInt): PtrInt; dcpcall;

implementation

uses
  LCLStrConsts, LazFileUtils, DCClassesUtf8, DCOSUtils, uShowMsg, uDebug,
  uTranslator, uGlobs;

function InputBox(Caption, Prompt: PAnsiChar; MaskInput: LongBool; Value: PAnsiChar; ValueMaxLen: Integer): LongBool; dcpcall;
var
  sValue: String;
begin
  Result:= False;
  sValue:= StrPas(Value);
  if ShowInputQuery(Caption, Prompt, MaskInput, sValue) then
    begin
      StrLCopy(Value, PAnsiChar(sValue), ValueMaxLen);
      Result:= True;
    end;
end;

function MessageBox(Text, Caption: PAnsiChar; Flags: Longint): Integer; dcpcall;
begin
  Result:= ShowMessageBox(Text, Caption, Flags);
end;

procedure SetDialogBoxResourceLRS(LRSData: String);
var
  LResource: TLResource;
begin
  LResource := LazarusResources.Find('TDialogBox','FORMDATA');
  if Assigned(LResource) then
    LResource.Value:= LRSData
  else
    LazarusResources.Add('TDialogBox','FORMDATA', LRSData);
end;

procedure SetDialogBoxResourceLFM(LFMData: String);
var
  LFMStream: TStringStream = nil;
  BinStream: TStringStream = nil;
begin
  try
    LFMStream:= TStringStream.Create(LFMData);
    BinStream:= TStringStream.Create('');
    LRSObjectTextToBinary(LFMStream, BinStream);
    SetDialogBoxResourceLRS(BinStream.DataString);
  finally
    if Assigned(LFMStream) then
      FreeAndNil(LFMStream);
    if Assigned(BinStream) then
      FreeAndNil(BinStream);
  end;
end;

function DialogBox(DlgProc: TDlgProc): LongBool;
var
  Dialog: TDialogBox = nil;
begin
  Dialog:= TDialogBox.Create(DlgProc);
  try
    with Dialog do
    begin
      TThread.Synchronize(nil, @ShowDialogBox);
      Result:= FResult;
    end;
  finally
    if Assigned(Dialog) then
      FreeAndNil(Dialog);
  end;
end;

function DialogBoxLFM(LFMData: Pointer; DataSize: LongWord; DlgProc: TDlgProc): LongBool;dcpcall;
var
  DataString: String;
begin
  if Assigned(LFMData) and (DataSize > 0) then
  begin
    SetString(DataString, LFMData, DataSize);
    SetDialogBoxResourceLFM(DataString);
    Result := DialogBox(DlgProc);
  end
  else
    Result := False;
end;

function DialogBoxLRS(LRSData: Pointer; DataSize: LongWord; DlgProc: TDlgProc): LongBool; dcpcall;
var
  DataString: String;
begin
  if Assigned(LRSData) and (DataSize > 0) then
  begin
    SetString(DataString, LRSData, DataSize);
    SetDialogBoxResourceLRS(DataString);
    Result := DialogBox(DlgProc);
  end
  else
    Result := False;
end;

function DialogBoxLFMFile(lfmFileName: PAnsiChar; DlgProc: TDlgProc): LongBool;dcpcall;
var
  lfmStringList: TStringListEx;
begin
  if Assigned(lfmFileName) then
  begin
    lfmStringList:= TStringListEx.Create;
    try
      lfmStringList.LoadFromFile(lfmFileName);
      SetDialogBoxResourceLFM(lfmStringList.Text);
      Result := DialogBox(DlgProc);
    finally
      FreeAndNil(lfmStringList);
    end;
  end
  else
    Result := False;
end;

function SendDlgMsg(pDlg: PtrUInt; DlgItemName: PAnsiChar; Msg, wParam, lParam: PtrInt): PtrInt; dcpcall;
var
  DialogBox: TDialogBox;
  Control: TControl;
  sText: String;
  I: Integer;
  Rect: TRect;
  Key: Word;
begin
  DialogBox:= TDialogBox(Pointer(pDlg));
  // find component by name
  for I:= 0 to DialogBox.ComponentCount - 1 do
    begin
      Control:= TControl(DialogBox.Components[I]);
      if CompareText(Control.Name, DlgItemName) = 0 then Break;
    end;
  // process message
  case Msg of
  DM_CLOSE:
    begin
      DialogBox.Close;
      if wParam <> -1 then
        DialogBox.ModalResult:= wParam;
    end;
  DM_ENABLE:
    begin
      Result:= PtrInt(Control.Enabled);
      if wParam <> -1 then
        Control.Enabled:= Boolean(wParam);
    end;
  DM_GETCHECK:
    begin
      if Control is TCheckBox then
        Result:= PtrInt((Control as TCheckBox).State);
      if Control is TRadioButton then
        Result := PtrInt((Control as TRadioButton).Checked);
    end;
  DM_GETDLGBOUNDS:
    begin
      Rect.Left:= DialogBox.Left;
      Rect.Top:= DialogBox.Top;
      Rect.Right:= DialogBox.Left + DialogBox.Width;
      Rect.Bottom:= DialogBox.Top + DialogBox.Height;
      Result:= PtrInt(@Rect);
    end;
  DM_GETDLGDATA:
    begin
      Result:= DialogBox.Tag;
    end;
  DM_GETDROPPEDDOWN:
    begin
      if Control is TComboBox then
        Result:= PtrInt((Control as TComboBox).DroppedDown);
    end;
  DM_GETITEMBOUNDS:
    begin
      Rect.Left:= Control.Left;
      Rect.Top:= Control.Top;
      Rect.Right:= Control.Left + Control.Width;
      Rect.Bottom:= Control.Top + Control.Height;
      Result:= PtrInt(@Rect);
    end;
  DM_GETITEMDATA:
    begin
      Result:= Control.Tag;
    end;
  DM_LISTADD:
    begin
      sText:= PAnsiChar(wParam);
      if Control is TComboBox then
        Result:= TComboBox(Control).Items.AddObject(sText, TObject(Pointer(lParam)))
      else if Control is TListBox then
        Result:= TListBox(Control).Items.AddObject(sText, TObject(Pointer(lParam)))
      else if Control is TMemo then
        Result:= TMemo(Control).Lines.AddObject(sText, TObject(Pointer(lParam)));
    end;
  DM_LISTADDSTR:
    begin
      sText:= PAnsiChar(wParam);
      if Control is TComboBox then
        Result:= TComboBox(Control).Items.Add(sText)
      else if Control is TListBox then
        Result:= TListBox(Control).Items.Add(sText)
      else if Control is TMemo then
        Result:= TMemo(Control).Lines.Add(sText);
    end;
  DM_LISTDELETE:
    begin
      if Control is TComboBox then
        TComboBox(Control).Items.Delete(wParam)
      else if Control is TListBox then
        TListBox(Control).Items.Delete(wParam)
      else if Control is TMemo then
        TMemo(Control).Lines.Delete(wParam);
    end;
  DM_LISTINDEXOF:
    begin
      sText:= PAnsiChar(lParam);
      if Control is TComboBox then
        Result:= TComboBox(Control).Items.IndexOf(sText)
      else if Control is TListBox then
        Result:= TListBox(Control).Items.IndexOf(sText)
      else if Control is TMemo then
        Result:= TMemo(Control).Lines.IndexOf(sText);
    end;
  DM_LISTINSERT:
    begin
      sText:= PAnsiChar(lParam);
      if Control is TComboBox then
        TComboBox(Control).Items.Insert(wParam, sText)
      else if Control is TListBox then
        TListBox(Control).Items.Insert(wParam, sText)
      else if Control is TMemo then
        TMemo(Control).Lines.Insert(wParam, sText);
    end;
  DM_LISTGETCOUNT:
    begin
      if Control is TComboBox then
        Result:= TComboBox(Control).Items.Count
      else if Control is TListBox then
        Result:= TListBox(Control).Items.Count
      else if Control is TMemo then
        Result:= TMemo(Control).Lines.Count;
    end;
  DM_LISTGETDATA:
    begin
      if Control is TComboBox then
        Result:= PtrInt(TComboBox(Control).Items.Objects[wParam])
      else if Control is TListBox then
        Result:= PtrInt(TListBox(Control).Items.Objects[wParam])
      else if Control is TMemo then
        Result:= PtrInt(TMemo(Control).Lines.Objects[wParam]);
    end;
  DM_LISTGETITEM:
    begin
      if Control is TComboBox then
        sText:= TComboBox(Control).Items[wParam]
      else if Control is TListBox then
        sText:= TListBox(Control).Items[wParam]
      else if Control is TMemo then
        sText:= TMemo(Control).Lines[wParam];
      Result:= PtrInt(PAnsiChar(sText));
    end;
  DM_LISTGETITEMINDEX:
    begin
      Result:= -1;
      if Control is TComboBox then
        Result:= TComboBox(Control).ItemIndex
      else if Control is TListBox then
        Result:= TListBox(Control).ItemIndex
      else if Control is TRadioGroup then
        Result:= TRadioGroup(Control).ItemIndex;
    end;
  DM_LISTSETITEMINDEX:
    begin
      if Control is TComboBox then
        TComboBox(Control).ItemIndex:= wParam
      else if Control is TListBox then
        TListBox(Control).ItemIndex:= wParam
      else if Control is TRadioGroup then
        TRadioGroup(Control).ItemIndex:= wParam;
    end;
  DM_LISTUPDATE:
    begin
      sText:= PAnsiChar(lParam);
      if Control is TComboBox then
        TComboBox(Control).Items[wParam]:= sText
      else if Control is TListBox then
        TListBox(Control).Items[wParam]:= sText
      else if Control is TMemo then
        TMemo(Control).Lines[wParam]:= sText;
    end;
  DM_GETTEXT:
    begin
      if Control is TButton then
        sText:= TButton(Control).Caption
      else if Control is TComboBox then
        sText:= TComboBox(Control).Text
      else if Control is TMemo then
        sText:= TMemo(Control).Text
      else if Control is TEdit then
        sText:= TEdit(Control).Text
      else if Control is TGroupBox then
        sText:= TGroupBox(Control).Caption
      else if Control is TLabel then
        sText:= TLabel(Control).Caption
      else if Control is TFileNameEdit then
        sText:= TFileNameEdit(Control).Text;
      Result:= PtrInt(PAnsiChar(sText));
    end;
  DM_KEYDOWN:
    begin
      Key:= wParam;
      DialogBox.KeyDown(Key, GetKeyShiftState);
      Result:= Key;
    end;
  DM_KEYUP:
    begin
      Key:= wParam;
      DialogBox.KeyUp(Key, GetKeyShiftState);
      Result:= Key;
    end;
  DM_REDRAW:
    begin
      DialogBox.Repaint;
    end;
  DM_SETCHECK:
    begin
      if Control is TCheckBox then
        begin
          Result:= PtrInt((Control as TCheckBox).State);
          (Control as TCheckBox).State:= TCheckBoxState(wParam)
        end;
      if Control is TRadioButton then
        begin
          Result := PtrInt((Control as TRadioButton).Checked);
          (Control as TRadioButton).Checked:= Boolean(wParam);
        end;
    end;
  DM_LISTSETDATA:
    begin
      if Control is TComboBox then
        TComboBox(Control).Items.Objects[wParam]:= TObject(Pointer(lParam))
      else if Control is TListBox then
        TListBox(Control).Items.Objects[wParam]:= TObject(Pointer(lParam))
      else if Control is TMemo then
        TMemo(Control).Lines.Objects[wParam]:= TObject(Pointer(lParam));
    end;
  DM_SETDLGBOUNDS:
    begin
      Rect:= PRect(wParam)^;
      DialogBox.Left:= Rect.Left;
      DialogBox.Top:= Rect.Top;
      DialogBox.Width:= Rect.Right - Rect.Left;
      DialogBox.Height:= Rect.Bottom - Rect.Top;
    end;
  DM_SETDLGDATA:
    begin
      Result:= DialogBox.Tag;
      DialogBox.Tag:= wParam;
    end;
  DM_SETDROPPEDDOWN:
    begin
      if Control is TComboBox then
        (Control as TComboBox).DroppedDown:= Boolean(wParam);
    end;
  DM_SETFOCUS:
    begin
      if Control.Visible then
        (Control as TWinControl).SetFocus;
    end;
  DM_SETITEMBOUNDS:
    begin
      Rect:= PRect(wParam)^;
      Control.Left:= Rect.Left;
      Control.Top:= Rect.Top;
      Control.Width:= Rect.Right - Rect.Left;
      Control.Height:= Rect.Bottom - Rect.Top;
    end;
  DM_SETITEMDATA:
    begin
      Control.Tag:= wParam;
    end;
  DM_SETMAXTEXTLENGTH:
    begin
      Result:= -1;
      if Control is TComboBox then
        begin
          Result:= (Control as TComboBox).MaxLength;
          (Control as TComboBox).MaxLength:= wParam;
        end;
      if Control is TEdit then
        begin
          Result:= (Control as TEdit).MaxLength;
          (Control as TEdit).MaxLength:= wParam;
        end;
    end;
  DM_SETTEXT:
    begin
      sText:= PAnsiChar(wParam);
      if Control is TButton then
        TButton(Control).Caption:= sText
      else if Control is TComboBox then
        TComboBox(Control).Text:= sText
      else if Control is TMemo then
        TMemo(Control).Text:= sText
      else if Control is TEdit then
        TEdit(Control).Text:= sText
      else if Control is TGroupBox then
        TGroupBox(Control).Caption:= sText
      else if Control is TLabel then
        TLabel(Control).Caption:= sText
      else if Control is TFileNameEdit then
        TFileNameEdit(Control).Text:= sText;
    end;
  DM_SHOWDIALOG:
    begin
      if wParam = 0 then
        DialogBox.Hide;
      if wParam = 1 then
        DialogBox.Show;
    end;
  DM_SHOWITEM:
    begin
      Result:= PtrInt(Control.Visible);
      if wParam <> -1 then
        Control.Visible:= Boolean(wParam);
    end;
  end;
end;

{ TDialogBox }

procedure TDialogBox.ShowDialogBox;
begin
  FResult:= (ShowModal = mrOK);
end;

procedure TDialogBox.ProcessResource;
begin
  if not InitResourceComponent(Self, TForm) then
    if RequireDerivedFormResource then
      raise EResNotFound.CreateFmt(rsFormResourceSNotFoundForResourcelessFormsCreateNew, [ClassName])
  else
    DCDebug(Format(rsFormResourceSNotFoundForResourcelessFormsCreateNew, [ClassName]));
end;

function TDialogBox.InitResourceComponent(Instance: TComponent; RootAncestor: TClass): Boolean;

  function InitComponent(ClassType: TClass): Boolean;
  var
    ResName: String;
    Stream: TStream;
    Reader: TReader;
    DestroyDriver: Boolean;
    LazResource: TLResource;
    Driver: TAbstractObjectReader;
  begin
    Result := False;
    if (ClassType = TComponent) or (ClassType = RootAncestor) then
      Exit;
    if Assigned(ClassType.ClassParent) then
      Result := InitComponent(ClassType.ClassParent);

    Stream := nil;
    ResName := ClassType.ClassName;

    LazResource := LazarusResources.Find(ResName);
    if (LazResource <> nil) and (LazResource.Value <> '') then
      Stream := TLazarusResourceStream.CreateFromHandle(LazResource);
    //DCDebug('[InitComponent] CompResource found for ', ClassType.Classname);

    if Stream = nil then
      Exit;

    try
      //DCDebug('Form Stream "', ClassType.ClassName, '"');
      DestroyDriver := False;
      Reader := CreateLRSReader(Stream, DestroyDriver);
      if Assigned(FTranslator) then begin
        Reader.OnReadStringProperty:= @FTranslator.TranslateStringProperty;
      end;
      try
        Reader.ReadRootComponent(Instance);
      finally
        Driver := Reader.Driver;
        Reader.Free;
        if DestroyDriver then
          Driver.Free;
      end;
    finally
      Stream.Free;
    end;
    Result := True;
  end;

begin
  if Instance.ComponentState * [csLoading, csInline] <> []
  then begin
    // global loading not needed
    Result := InitComponent(Instance.ClassType);
  end
  else try
    BeginGlobalLoading;
    Result := InitComponent(Instance.ClassType);
    NotifyGlobalLoading;
  finally
    EndGlobalLoading;
  end;
end;

constructor TDialogBox.Create(DlgProc: TDlgProc);
var
  Path: String;
  Language: String;
  FileName: String;
begin
  FDlgProc:= DlgProc;

  FileName:= mbGetModuleName(DlgProc);
  Path:= ExtractFilePath(FileName) + 'language' + PathDelim;
  Language:= ExtractFileExt(ExtractFileNameOnly(gPOFileName));
  FileName:= Path + ExtractFileNameOnly(FileName) + Language + '.po';
  if mbFileExists(FileName) then FTranslator:= TTranslator.Create(FileName);

  inherited Create(nil);
end;

destructor TDialogBox.Destroy;
begin
  inherited Destroy;
  FTranslator.Free;
end;

procedure TDialogBox.DialogBoxShow(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_INITDIALOG,0,0);
end;

procedure TDialogBox.ButtonClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CLICK,0,0);
end;

procedure TDialogBox.ButtonEnter(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_GOTFOCUS,0,0);
end;

procedure TDialogBox.ButtonExit(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KILLFOCUS,0,0);
end;

procedure TDialogBox.ButtonKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYDOWN, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.ButtonKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYUP, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.ComboBoxClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CLICK,PtrInt((Sender as TComboBox).ItemIndex),0);
end;

procedure TDialogBox.ComboBoxDblClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_DBLCLICK,PtrInt((Sender as TComboBox).ItemIndex),0);
end;

procedure TDialogBox.ComboBoxChange(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    begin
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CHANGE, PtrInt((Sender as TComboBox).ItemIndex),0);
    end;
end;

procedure TDialogBox.ComboBoxEnter(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_GOTFOCUS,0,0);
end;

procedure TDialogBox.ComboBoxExit(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KILLFOCUS,0,0);
end;

procedure TDialogBox.ComboBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYDOWN, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.ComboBoxKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYUP, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.EditClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CLICK,0,0);
end;

procedure TDialogBox.EditDblClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_DBLCLICK,0,0);
end;

procedure TDialogBox.EditChange(Sender: TObject);
var
  sText: String;
begin
  if Assigned(fDlgProc) then
    begin
      sText:= (Sender as TEdit).Text;
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CHANGE, PtrInt(PAnsiChar(sText)), 0);
    end;
end;

procedure TDialogBox.EditEnter(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_GOTFOCUS,0,0);
end;

procedure TDialogBox.EditExit(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KILLFOCUS,0,0);
end;

procedure TDialogBox.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYDOWN, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.EditKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYUP, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.ListBoxClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    begin
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CLICK, PtrInt((Sender as TListBox).ItemIndex),0);
    end;
end;

procedure TDialogBox.ListBoxDblClick(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    begin
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_DBLCLICK, PtrInt((Sender as TListBox).ItemIndex),0);
    end;
end;

procedure TDialogBox.ListBoxSelectionChange(Sender: TObject; User: boolean);
begin
  if Assigned(fDlgProc) then
    begin
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CHANGE, PtrInt((Sender as TListBox).ItemIndex),0);
    end;
end;

procedure TDialogBox.ListBoxEnter(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_GOTFOCUS,0,0);
end;

procedure TDialogBox.ListBoxExit(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KILLFOCUS,0,0);
end;

procedure TDialogBox.ListBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYDOWN, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.ListBoxKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Assigned(fDlgProc) then
    fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_KEYUP, PtrInt(@Key), Integer(Shift));
end;

procedure TDialogBox.CheckBoxChange(Sender: TObject);
begin
  if Assigned(fDlgProc) then
    begin
      fDlgProc(PtrUInt(Pointer(Self)), PAnsiChar((Sender as TControl).Name), DN_CHANGE, PtrInt((Sender as TCheckBox).Checked),0);
    end;
end;

initialization
  {.$I fdialogbox.lrs}

end.

