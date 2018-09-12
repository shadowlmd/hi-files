unit _fopen;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

function ExecFileOpenDlg( const Title, Wild: String; var FileName: String ) : Boolean;

{ =================================================================== }

implementation

uses
  Views, Dialogs, Drivers, App, MyLib, MyViews, Objects, SysUtils,
  vpSysLow, vpUtils, _Working, _Res;

type
  PFileOpenDialog = ^TFileOpenDialog;
  TFileOpenDialog = object (TDialog)
    InputLine: PInputLine;

    FilBox: PMyListBox;
    DirBox: PMyListBox;
    DrvBox: PMyListBox;

    InfoPane: PInfoPane;
    InfoData: String;
    InfoPtr : PString;

    Path: String;
    Wild: String;

    constructor Init( const ATitle: String );
    destructor Done; virtual;
    procedure SetupDialog( AWild: String );
    procedure HandleEvent( var Event: TEvent ); virtual;
    function DataSize: Word; virtual;
    procedure GetData(var Rec); virtual;
    procedure SetData(var Rec); virtual;
  private
    procedure ReadDir;
    procedure UpdateInfoPane;
  end; { TFileOpenDialog }

/////////////////////////////////////////////////////////////////////
//
// TFileOpenDialog
//
/////////////////////////////////////////////////////////////////////

{ --------------------------------------------------------- }
{ Init                                                      }
{ --------------------------------------------------------- }

constructor TFileOpenDialog.Init(const ATitle: String);
var
  R: TRect;
  V: PView;
  S: PScrollBar;
begin
  R.Assign(0, 0, 76, 21);
  inherited Init(R, ATitle);
  Options := Options or ofCentered;

  R.Assign(2, 3, Size.X - 2, 4);
  InputLine := New(PInputLine, Init(R, Pred(SizeOf(String))));
  Insert(InputLine);

  R.Move(0, -1);
  Insert(New(PLabel, Init(R, 'Имя файла', InputLine)));

  R.Assign(31, 6, 32, Size.Y - 5);
  S := New(PScrollBar, Init(R));
  Insert(S);

  R.Assign(2, 6, 31, Size.Y - 5);
  FilBox := New(PMyListBox, Init(R, 1, S));
  Insert(FilBox);

  R.Move(0, -1); R.B.Y := Succ(R.A.Y);
  Insert(New(PLabel, Init(R, 'Файлы', FilBox)));

  R.Assign(59, 6, 60, Size.Y - 5);
  S := New(PScrollBar, Init(R));
  Insert(S);

  R.Assign(33, 6, 59, Size.Y - 5);
  DirBox := New(PMyListBox, Init(R, 1, S));
  Insert(DirBox);

  R.Move(0, -1); R.B.Y := Succ(R.A.Y);
  Insert(New(PLabel, Init(R, 'Каталоги', DirBox)));

  R.Assign(73, 6, 74, Size.Y - 5);
  S := New(PScrollBar, Init(R));
  Insert(S);

  R.Assign(61, 6, 73, Size.Y - 5);
  DrvBox := New(PMyListBox, Init(R, 1, S));
  Insert(DrvBox);

  R.Move(0, -1); R.B.Y := Succ(R.A.Y);
  Insert(New(PLabel, Init(R, 'Диски', DrvBox)));

  R.Assign(2, Size.Y - 5, Size.X - 2, Size.Y - 4);
  InfoPane := New(PInfoPane, Init(R, '%s', 1));
  Insert(InfoPane);

  InfoPtr  := @InfoData;
  InfoPane^.SetData(InfoPtr);

  R.Assign(2, Size.Y - 3, 12, Size.Y - 1);
  Insert(New(PButton, Init(R, 'OK', cmOk, bfDefault)));

  R.Move(12, 0);
  Insert(New(PButton, Init(R, 'Отмена', cmCancel, bfNormal)));

  SelectNext(False);

end; { Init }

{ --------------------------------------------------------- }
{ Done                                                      }
{ --------------------------------------------------------- }

destructor TFileOpenDialog.Done;
begin
  FilBox^.NewList(nil);
  DirBox^.NewList(nil);
  DrvBox^.NewList(nil);
  inherited Done;
end; { Done }

{ --------------------------------------------------------- }
{ SetupDialog                                               }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.SetupDialog(AWild: String);
var
  S: String;
  List : PStrings;
  Drive: Char;
  ValidDrives: DriveSet;
begin
  OpenWorking(LoadString(_SScanningDrives));
  AWild := ExpandFileName(AWild);
  Wild  := ExtractFileName(AWild);
  Path  := ExtractFilePath(AWild);
  List  := New(PStrings, Init(10, 10));
  GetValidDrives(ValidDrives);
  for Drive := 'C' to 'Z' do
  begin
    if Drive in ValidDrives then
    begin
      case SysGetDriveType(Drive) of
        dtFloppy    : S := 'Floppy';
        dtHDFAT     : S := 'FAT';
        dtHDHPFS    : S := 'HPFS';
        dtNovellNet : S := 'Novell';
        dtCDRom     : S := 'CDROM';
        dtLAN       : S := 'Network';
        dtHDNTFS    : S := 'NTFS';
        dtUnknown   : S := 'Unknown';
        dtTVFS      : S := 'TVFS';
        dtHDExt2    : S := 'Ext2';
        dtJFS       : S := 'JFS';
      else
        Continue;
      end;
      List^.Insert(AllocStr(Drive + ': ' + S));
    end;
  end;
  DrvBox^.NewList(List);
  CloseWorking;
end; { SetupDialog }

{ --------------------------------------------------------- }
{ DataSize                                                  }
{ --------------------------------------------------------- }

function TFileOpenDialog.DataSize: Word;
begin
  Result := SizeOf(String);
end; { DataSize }

{ --------------------------------------------------------- }
{ GetData                                                   }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.GetData(var Rec);
var
  S: String absolute Rec;
begin
  InputLine^.GetData(S);
  if RelativePath(S) then
    S := ExpandFileName(AddBackSlash(Path) + S);
end; { GetData }

{ --------------------------------------------------------- }
{ SetData                                                   }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.SetData(var Rec);
begin
  InputLine^.SetData(Rec);
  ReadDir;
end; { SetData }

{ --------------------------------------------------------- }
{ HandleEvent                                               }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.HandleEvent(var Event: TEvent);
var
  FileName: String;

  procedure DoSelFile;
  begin
    with FilBox^ do
      if Focused < Range then
        InputLine^.SetData(PString(List^.At(Focused))^);
  end; { DoSelFile }

  procedure DoSelDir;
  begin
    with DirBox^ do
      if Focused < Range then
      begin
        Path := AddBackSlash(Path) + PString(DirBox^.List^.At(DirBox^.Focused))^;
        Path := ExpandFilename(Path + SysPathSep);
        InputLine^.SetData(Wild);
        ReadDir;
      end;
  end; { DoSelDir }

  procedure DoSelDrv;
  var
    Drive: Char;
  begin
    with DrvBox^ do
      if Focused < Range then
      begin
        Drive := PString(DrvBox^.List^.At(DrvBox^.Focused))^[1];
        GetDir(Ord(Drive) - Ord('A') + 1, Path);
        InputLine^.SetData(Wild);
        ReadDir;
      end;
  end; { DoSelDrv }

begin
  if (Event.What = evCommand) and (Event.Command = cmOk) then
  begin
    if Current = FilBox then
      DoSelFile;

    GetData(FileName);

    if HasWildChars(FileName) then
    begin
      Wild := ExtractFileName(FileName);
      Path := ExtractFilePath(FileName);
      InputLine^.SetData(Wild);
      ReadDir;
      ClearEvent(Event);
      Exit;
    end;
  end;

  inherited HandleEvent(Event);
  case Event.What of
    evBroadcast:
      case Event.Command of
        cmFocusMoved:
          if Current = FilBox then
            UpdateInfoPane;
        cmListItemSelected:
          if Current = FilBox then
            DoSelFile
          else if Current = DirBox then
            DoSelDir
          else if Current = DrvBox then
            DoSelDrv
      end;
  end;
end; { HandleEvent }

{ --------------------------------------------------------- }
{ UpdateInfoPane                                            }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.UpdateInfoPane;
begin
  with FilBox^ do
  begin
    if Focused < Range then
      InfoData := AtPath(PString(List^.At(Focused))^, Path)
    else
      InfoData := '';

    InfoPane^.DrawView;

  end;
end; { UpdateInfoPane }

{ --------------------------------------------------------- }
{ ReadDir                                                   }
{ --------------------------------------------------------- }

procedure TFileOpenDialog.ReadDir;
var
  EC: Integer;
  SR: TSearchRec;
  FilList: PNoCaseStrCollection;
  DirList: PNoCaseStrCollection;
begin
  FilBox^.NewList(nil);
  DirBox^.NewList(nil);

  FilList := New(PNoCaseStrCollection, Init(100, 100));
  DirList := New(PNoCaseStrCollection, Init(100, 100));

  EC := FindFirst(AtPath('*.*', Path), faAnyFile, SR);
  while EC = 0 do
  begin
    if (SR.Attr and faDirectory) <> 0 then
    begin
      if SR.Name <> '.' then
        DirList^.Insert(AllocStr(SR.Name));
    end
    else if WildMatch(SR.Name, Wild) then
      FilList^.Insert(AllocStr(SR.Name));
    EC := FindNext(SR);
  end;
  FindClose(SR);

  FilBox^.NewList(FilList);
  DirBox^.NewList(DirList);

  UpdateInfoPane;

end; { ReadDir }

/////////////////////////////////////////////////////////////////////
//
// ExecFileOpenDlg
//
/////////////////////////////////////////////////////////////////////

function ExecFileOpenDlg(const Title, Wild: String; var FileName: String) : Boolean;
var
  D: PFileOpenDialog;
begin
  D := New(PFileOpenDialog, Init(Title));
  D^.SetupDialog(Wild);
  Result := Application^.ExecuteDialog(D, @FileName) = cmOk;
end; { ExecFileOpenDlg }

end.

