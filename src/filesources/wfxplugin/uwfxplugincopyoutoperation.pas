unit uWfxPluginCopyOutOperation;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uFileSourceCopyOperation,
  uFileSource,
  uFileSourceOperation,
  uFileSourceOperationOptions,
  uFileSourceOperationOptionsUI,
  uFile,
  uWfxPluginFileSource,
  uWfxPluginUtil;

type

  { TWfxPluginCopyOutOperation }

  TWfxPluginCopyOutOperation = class(TFileSourceCopyOutOperation)

  private
    FWfxPluginFileSource: IWfxPluginFileSource;
    FOperationHelper: TWfxPluginOperationHelper;
    FCallbackDataClass: TCallbackDataClass;
    FSourceFilesTree: TFileTree;  // source files including all files/dirs in subdirectories
    FStatistics: TFileSourceCopyOperationStatistics; // local copy of statistics
    // Options
    FInfoOperation: LongInt;
    procedure SetNeedsConnection(AValue: Boolean);

  protected
    function UpdateProgress(SourceName, TargetName: PAnsiChar; PercentDone: Integer): Integer;

  public
    constructor Create(aSourceFileSource: IFileSource;
                       aTargetFileSource: IFileSource;
                       var theSourceFiles: TFiles;
                       aTargetPath: String); override;

    destructor Destroy; override;

    procedure Initialize; override;
    procedure MainExecute; override;
    procedure Finalize; override;

    class function GetOptionsUIClass: TFileSourceOperationOptionsUIClass; override;

    property NeedsConnection: Boolean read FNeedsConnection write SetNeedsConnection;

  end;

implementation

uses
  fWfxPluginCopyMoveOperationOptions, WfxPlugin;

// -- TWfxPluginCopyOutOperation ---------------------------------------------

procedure TWfxPluginCopyOutOperation.SetNeedsConnection(AValue: Boolean);
begin
  FNeedsConnection:= AValue;
  if (FNeedsConnection = False) then
    FInfoOperation:= FS_STATUS_OP_GET_MULTI_THREAD
  else if (SourceFiles.Count > 1) then
    FInfoOperation:= FS_STATUS_OP_GET_MULTI
  else
    FInfoOperation:= FS_STATUS_OP_GET_SINGLE;
end;

function TWfxPluginCopyOutOperation.UpdateProgress(SourceName, TargetName: PAnsiChar;
                                                   PercentDone: Integer): Integer;
var
  iTemp: Int64;
begin
  Result := 0;

  //DCDebug('SourceName=', SourceName, #32, 'TargetName=', TargetName, #32, 'PercentDone=', IntToStr(PercentDone));

  if State = fsosStopping then  // Cancel operation
    Exit(1);

  with FStatistics do
  begin
    if Assigned(SourceName) then begin
      FStatistics.CurrentFileFrom:= SourceName;
    end;
    if Assigned(TargetName) then begin
      FStatistics.CurrentFileTo:= TargetName;
    end;

    iTemp:= CurrentFileTotalBytes * PercentDone div 100;
    DoneBytes := DoneBytes + (iTemp - CurrentFileDoneBytes);
    CurrentFileDoneBytes:= iTemp;

    UpdateStatistics(FStatistics);
  end;

  if not AppProcessMessages(True) then
    Exit(1);
end;

constructor TWfxPluginCopyOutOperation.Create(aSourceFileSource: IFileSource;
                                              aTargetFileSource: IFileSource;
                                              var theSourceFiles: TFiles;
                                              aTargetPath: String);
begin
  FWfxPluginFileSource:= aSourceFileSource as IWfxPluginFileSource;
  with FWfxPluginFileSource do
  FCallbackDataClass:= TCallbackDataClass(WfxOperationList.Objects[PluginNumber]);

  inherited Create(aSourceFileSource, aTargetFileSource, theSourceFiles, aTargetPath);

  SetNeedsConnection(FNeedsConnection);
end;

destructor TWfxPluginCopyOutOperation.Destroy;
begin
  inherited Destroy;
end;

procedure TWfxPluginCopyOutOperation.Initialize;
var
  TreeBuilder: TWfxTreeBuilder;
begin
  with FWfxPluginFileSource do
  begin
    WfxModule.WfxStatusInfo(SourceFiles.Path, FS_STATUS_START, FInfoOperation);
    FCallbackDataClass.UpdateProgressFunction:= @UpdateProgress;
    UpdateProgressFunction:= @UpdateProgress;
    // Get initialized statistics; then we change only what is needed.
    FStatistics := RetrieveStatistics;

    TreeBuilder := TWfxTreeBuilder.Create(@AskQuestion, @CheckOperationState);
    try
      TreeBuilder.WfxModule:= WfxModule;
      TreeBuilder.SymLinkOption:= fsooslFollow;
      TreeBuilder.BuildFromFiles(SourceFiles);
      FSourceFilesTree := TreeBuilder.ReleaseTree;
      FStatistics.TotalFiles := TreeBuilder.FilesCount;
      FStatistics.TotalBytes := TreeBuilder.FilesSize;
    finally
      FreeAndNil(TreeBuilder);
    end;
  end;

  if Assigned(FOperationHelper) then
    FreeAndNil(FOperationHelper);

  FOperationHelper := TWfxPluginOperationHelper.Create(
                        FWfxPluginFileSource,
                        @AskQuestion,
                        @RaiseAbortOperation,
                        @CheckOperationState,
                        @UpdateStatistics,
                        @ShowCompareFilesUI,
                        @ShowCompareFilesUIByFileObject,
                        Thread,
                        wpohmCopyOut,
                        TargetPath);

  FOperationHelper.RenameMask := RenameMask;
  FOperationHelper.FileExistsOption := FileExistsOption;
  FOperationHelper.CopyAttributesOptions := CopyAttributesOptions;

  FOperationHelper.Initialize;
end;

procedure TWfxPluginCopyOutOperation.MainExecute;
begin
  FOperationHelper.ProcessTree(FSourceFilesTree, FStatistics);
end;

procedure TWfxPluginCopyOutOperation.Finalize;
begin
  with FWfxPluginFileSource do
  begin
    WfxModule.WfxStatusInfo(SourceFiles.Path, FS_STATUS_END, FInfoOperation);
    FCallbackDataClass.UpdateProgressFunction:= nil;
    UpdateProgressFunction:= nil;
  end;
  FileExistsOption := FOperationHelper.FileExistsOption;
  FOperationHelper.Free;
end;

class function TWfxPluginCopyOutOperation.GetOptionsUIClass: TFileSourceOperationOptionsUIClass;
begin
  Result := TWfxPluginCopyOutOperationOptionsUI;
end;

end.

