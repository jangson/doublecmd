unit uVfsListOperation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uFileSourceListOperation,
  uVfsFileSource,
  uFileSource;

type

  TVfsListOperation = class(TFileSourceListOperation)
  private
    FVfsFileSource: IVfsFileSource;
  public
    constructor Create(aFileSource: IFileSource; aPath: String); override;
    procedure MainExecute; override;
  end;

implementation

uses
  LCLProc, DCFileAttributes, uFile, uVfsModule, uDCUtils;

constructor TVfsListOperation.Create(aFileSource: IFileSource; aPath: String);
begin
  FFiles := TFiles.Create(aPath);
  FVfsFileSource := aFileSource as IVfsFileSource;
  inherited Create(aFileSource, aPath);
end;

procedure TVfsListOperation.MainExecute;
var
  I : Integer;
  aFile: TFile;
begin
  FFiles.Clear;

  with FVfsFileSource do
  for I := 0 to VfsFileList.Count - 1 do
    begin
      CheckOperationState;
      if VfsFileList.Enabled[I] then
      begin
        aFile := TVfsFileSource.CreateFile(Path);
        aFile.Name:= VfsFileList.Name[I];
        aFile.Attributes:= FILE_ATTRIBUTE_NORMAL or FILE_ATTRIBUTE_VIRTUAL;
        aFile.LinkProperty.LinkTo:= mbExpandFileName(VfsFileList.FileName[I]);
        FFiles.Add(aFile);
      end;
    end;
  for I:= 0 to gVfsModuleList.Count - 1 do
    begin
      CheckOperationState;
      if TVfsModule(gVfsModuleList.Objects[I]).Visible then
      begin
        aFile := TVfsFileSource.CreateFile(Path);
        aFile.Name:= gVfsModuleList.Strings[I];
        FFiles.Add(aFile);
      end;
    end;
end;

end.

