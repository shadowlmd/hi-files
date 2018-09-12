unit Import;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses _FAreas;

function ImportArea( ParentArea: PFileArea ) : Boolean;
function ImportEcho : Boolean;
function ImportLinks: Boolean;

{ =================================================================== }

implementation

uses
  Objects, SysUtils, MyLib, Views, Dialogs, App, _RES, _CFG, _fopen,
  MsgBox, _LOG, _MapFile, _Working, VpUtils, MsgAPI, HiFiHelp, StdDlg;

// WARNING: StdDlg.Pas line #701 should be:
// FindFirst(Tmp, Directory shl 8 or AnyFile, S);

const
  STREAM_BUFFER_SIZE = 4096;

{ --------------------------------------------------------- }
{ ImportTree                                                }
{ --------------------------------------------------------- }

procedure ImportTree( const Root: String; ParentArea: PFileArea );
var
  Info: record
    Accepted: Integer;
    Rejected: Integer;
  end;

  procedure ScanDir( Deep: String );
  var
    R: SysUtils.TSearchRec;
    DosError : Integer;
    Area : PFileArea;
    LevelName: String;
    LevelPath: String;

    function TargetOk: Boolean;
    begin
      try
        if FileBase^.GetArea( LevelName ) <> nil then
          raise Exception.Create( LoadString(_SNameExists) );
        if Filebase^.GetAreaByPath( LevelPath ) <> nil then
          raise Exception.Create( LoadString(_SDLPathExists) );
        if not DirExists( LevelPath ) then
          raise Exception.Create( LoadString(_SDLPathNotExists) );
        Result := True;
        Exit;
      except
        on E: Exception do
          begin
            Inc( Info.Rejected );
            Log^.Write( ll_Warning, Format(LoadString(_SAreaRejected), [LevelName, E.Message]) );
            ShowLog;
          end;
      end;
      Result := False;
    end; { TargetOk }

  begin
    DosError := SysUtils.FindFirst(
      AddBackSlash(AddBackSlash(Root) + Deep) + '*.*',
      faDirectory shl 8 or faAnyFile, R );
    while DosError = 0 do
    begin
      if (R.Name <> '.') and (R.Name <> '..') then
      begin
        LevelName := AddBackSlash(Deep) + R.Name;
        LevelPath := AddBackSlash(Root) + LevelName;
        if TargetOk then
        begin
          New( Area, Init( LevelName ) );
          if ParentArea <> nil then
            ParentArea^.Clone( Area );
          Area^.DL_Path^.FreeAll;
          with Area^ do
          begin
            DL_Path^.Insert( AllocStr(LevelPath) );
            ReplaceStr( FilesBbs, AtPath('files.bbs', LevelPath) );
          end;
          Inc( Info.Accepted );
          FileBase^.Insert( Area );
          FileBase^.Modified := True;
        end;
        ScanDir( LevelName );
      end;
      DosError := SysUtils.FindNext( R );
    end;
    SysUtils.FindClose( R );
  end; { ScanDir }

begin
  Info.Accepted := 0;
  Info.Rejected := 0;
  OpenWorking( LoadString(_SImportingTree) );
  try
    ScanDir( '' );
  finally
    CloseWorking;
  end;
  MessageBox( Format(LoadString(_SImportSummary), [Info.Accepted, Info.Rejected]), nil, mfInformation + mfOkButton );
end; { ImportTree }

{ --------------------------------------------------------- }
{ Import_DirTree                                            }
{ --------------------------------------------------------- }

procedure Import_DirTree( ParentArea: PFileArea );
var
  D: PDialog;
  SaveDir: String;
  Root: String;
begin
  SaveDir := GetCurrentDir;
  D := New( PChDirDialog, Init( cdNormal, 100 ) );
  if Application^.ExecuteDialog( D, nil ) = cmOk then
  begin
    Root := GetCurrentDir;
    SetCurrentDir( SaveDir );
    ImportTree( Root, ParentArea );
  end
  else
    SetCurrentDir( SaveDir );
end; { Import_DirTree }

{ --------------------------------------------------------- }
{ Import_BlstBbs                                            }
{ --------------------------------------------------------- }

procedure Import_BlstBbs;
var
  S: String;
  Key : String;
  Val : String;
  Map : TMappedFile;
  Area: PFileArea;
  Info: record
          NAreas, NEchoes: Integer;
        end;


 procedure MakeNewArea( const AreaTag: String );
 var
   Q: Integer;
   T: String;
 begin
   Q := 0;
   T := AreaTag;
   Area := FileBase^.GetArea( T );
   while Area <> nil do
   begin
     Inc(Q);
     T := Format( '%s (%d)', [AreaTag, Q] );
     Area := FileBase^.GetArea( T );
   end;
   Area := New( PFileArea, Init(T) );
   FileBase^.Insert( Area );
   Inc( Info.NAreas );
   FileBase^.Modified := True;
 end; { MakeNewArea }

 procedure AttachFileEcho( const EchoTag: String );
 var
   Echo: PFileEcho;
 begin
   if FileBase^.GetEcho( EchoTag ) <> nil then Exit;
   Echo := New( PFileEcho, Init(EchoTag) );
   FileBase^.EchoList^.Insert( Echo );
   Echo^.Area := Area;
   Inc( Info.NEchoes );
   FileBase^.Modified := True;
 end; { AttachFileEcho }

begin
  S := '*.dir';
  if not ExecFileOpenDlg(LoadString(_SImportBlstCaption), S, S) then Exit;

  if not FileExists( S ) then
  begin
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  OpenWorking( Format(LoadString(_SImportingBlst), [S]) );
  Log^.Write( ll_Service, Format(LoadString(_SImportingBlst), [S]) );
  try
    Map.Init( S );
    OpenProgress( Map.GetSize );
    FillChar( Info, SizeOf(Info), #0 );
    Area := nil;
    while Map.GetLine( S ) do
    begin
      UpdateProgress( Map.GetPos );
      StripComment( S );
      if S = '' then Continue;
      SplitPair( S, Key, Val );
      if JustSameText( Key, 'Name' ) then
        MakeNewArea( Val )
      else if Area = nil then
        Log^.Write( ll_Warning, LoadString(_SLogAreaNameMissing) )
      else
      begin
        if JustSameText( Key, 'SearchNew' ) then
          Area^.fScan := TSwitch( StrToBool(Val) )
        else if JustSameText( Key, 'SortFiles' ) then
          Area^.fSorted := TSwitch( StrToBool(Val) )
        else if JustSameText( Key, 'EraseFiles' ) then
          Continue
        else if JustSameText( Key, 'TicArea' ) then
          AttachFileEcho( Val )
        else if JustSameText( Key, 'FilesID' ) then
          ReplaceStr( Area^.FilesBbs, Val )
        else if JustSameText( Key, 'Exclude' ) then
          Continue
        else if JustSameText( Key, 'Level' ) then
          Continue
        else if JustSameText( Key, 'Path' ) then
        begin
          Area^.DL_Path^.AtInsert( 0, AllocStr(Val) );
          if (Area^.FilesBbs = nil) or (Area^.FilesBbs^ = '') then
            ReplaceStr( Area^.FilesBbs, AtPath( FILES_BBS, Val ) );
        end
        else if JustSameText( Key, 'Add' ) then
          Area^.DL_Path^.Insert( AllocStr(ExtractWord( 1, Val, [','] ) ))
        else
          Log^.Write( ll_Warning, Format(LoadString(_SBadLineIgnored), [S] ));
      end;
    end
  finally
    Map.Done;
    CloseWorking;
  end;
  MessageBox( Format(LoadString(_SBlstBbsSummary), [Info.NAreas, Info.NEchoes]), nil, mfInformation + mfOkButton );
end; { Import_BlstBbs }

{ --------------------------------------------------------- }
{ ImportArea                                                }
{ --------------------------------------------------------- }

function ImportArea( ParentArea: PFileArea ) : Boolean;
const
  bDirTree = 0;
  bBlstBbs = 1;
var
  D: PDialog;
  Data: Longint;
begin
  Result := False;
  D := PDialog( Res^.Get('IMP_AREA') );
  D^.HelpCtx := hcImportAreas;
  Data := bDirTree;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    case Data of
        bDirTree : Import_DirTree( ParentArea );
        bBLstBbs : Import_BlstBbs;
      else
        MessageBox( 'Under construction ;-)', nil, mfInformation + mfOkButton );
    end;
    Result := True;
  end;
  if Log^.HasWarnings then
    ShowLog;
end; { ImportArea }


{ --------------------------------------------------------- }
{ Import_HiFiles                                            }
{ --------------------------------------------------------- }

procedure Import_HiFiles;
var
  S: String;
  A: TAddress;
  j: Integer;
  Key  : String;
  Value: String;
  Map  : TMappedFile;
  Echo : PFileEcho;
  Area : PFileArea;
  EchoTag : String;
  EchoDir : String;
  Info : record
           Created: Integer;
           Reused : Integer;
         end;
begin
  S := '*.Ctl';
  if not ExecFileOpenDlg(LoadString(_SImportHiFiCaption), S, S) then Exit;

  if not FileExists( S ) then
  begin
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  OpenWorking( Format(LoadString(_SImportingHiFi), [S]) );
  Log^.Write( ll_Service, Format(LoadString(_SImportingHiFi), [S]) );
  try
    Map.Init( S );
    OpenProgress( Map.GetSize );
    Echo := nil;
    FillChar( Info, SizeOf(Info), 0 );
    while Map.GetLine( S ) do
    begin
      UpdateProgress( Map.GetPos );
      StripComment( S );
      if S = '' then Continue;
      SplitPair( S, Key, Value );
      if JustSameText( Key, 'Area' ) then
      begin
        FileBase^.Modified := True;
        EchoTag := ExtractWord( 1, Value, BLANK );
        EchoDir := ExtractWord( 2, Value, BLANK );
        Echo    := FileBase^.GetEcho( EchoTag );
        if Echo <> nil then
        begin
          Log^.Write( ll_Warning, Format(LoadString(_SLogJustAddLinks), [EchoTag] ));
          Inc( Info.Reused );
        end
        else
        begin
          Log^.Write( ll_Protocol, Format(LoadString(_SLogEchoCreated), [EchoTag] ));
          Inc( Info.Created );
          Echo := New( PFileEcho, Init( EchoTag ) );
          if EchoDir = '' then
            Log^.Write( ll_Expand, LoadString(_SLogPassthrough) )
          else
          begin
            Log^.Write( ll_Expand, Format(LoadString(_SLogParking), [EchoDir]));
            Area := FileBase^.GetAreaByPath( EchoDir );
            if Area = nil then
            begin
              Area := New( PFileArea, Init( 'FileEcho: ' + EchoTag ) );
              Log^.Write( ll_Protocol, Format(LoadString(_SLogNewHostCreated), [Area^.Name^]));
              Area^.DL_Path^.Insert( AllocStr( EchoDir ) );
              ReplaceStr( Area^.FilesBbs, AtPath( FILES_BBS, EchoDir ) );
              ReplaceStr( Area^.Group, FILE_ECHO_GROUP );
              FileBase^.Insert( Area );
              if not DirExists( EchoDir ) and not CreateDirTree( EchoDir ) then
                Log^.Write( ll_Warning, Format(LoadString(_SMkDirFailed), [EchoDir] ));
            end;
            Echo^.Area := Area;
          end;
          FileBase^.EchoList^.Insert( Echo );
        end;
      end
      else if Echo = nil then
      begin
        Log^.Write( ll_Warning, LoadString(_SLogAreaNameMissing) );
        Continue;
      end
      else if JustSameText( Key, 'ReceiveFrom' ) then
      begin
        for j := 1 to WordCount( Value, BLANK ) do
        begin
          if SafeAddr( ExtractWord( j, Value, BLANK ), A ) then
            Echo^.Uplinks^.Insert( NewAddr(A) )
          else
            Log^.Write( ll_Warning, Format(LoadString(_SBadULAddr), [Value]) );
        end;
      end
      else if JustSameText( Key, 'SendTo' ) then
      begin
        for j := 1 to WordCount( Key, BLANK ) do
        begin
          if SafeAddr( ExtractWord( j, Value, BLANK ), A ) then
            Echo^.Downlinks^.Insert( NewAddr(A) )
          else
            Log^.Write( ll_Warning, Format(LoadString(_SBadDLAddr), [Value]) );
        end;
      end
      else if JustSameText( Key, 'Hook' ) then
      begin
        Echo^.Hooks^.Add( Value );
      end
      else
      begin
        Log^.Write( ll_Warning, Format(LoadString(_SBadLineIgnored), [S] ))
      end;
    end;
  finally
    Map.Done;
    CloseWorking;
  end;
  MessageBox( Format(LoadString(_SImportEchoSummary), [Info.Created, Info.Reused]), nil, mfInformation + mfOkButton );
end; { Import_HiFiles }

{ --------------------------------------------------------- }
{ Import_AllFixBin                                          }
{ --------------------------------------------------------- }

procedure Import_AllFixBin;
const
  // Attribute bits for the fileecho records (attrib)
  _announce   = $0001;
  _replace    = $0002;
  _convertall = $0004;
  _passthru   = $0008;
  _dupecheck  = $0010;
  _fileidxxx  = $0020;
  _visible    = $0040;
  _tinysb     = $0080;
  _Security   = $0100;
  _NoTouch    = $0200;
  _SendOrig   = $0400;
  _AddGifSpecs= $0800;
  _VirusScan  = $1000;
  _UpdateMagic= $2000;
  _UseFDB     = $4000;
  _TouchAV    = $8000;

  // Attribute bits for the fileecho records (attrib2)
  _Unique     = $0001;
  _AutoAdded  = $0002;
  _ConvertInc = $0004;
  _CompUnknown= $0008;

  // Attribute bits for the systems in the system list
  _SendTo      = $0001;
  _ReceiveFrom = $0002;
  _PreRelease  = $0004;
  _Inactive    = $0008;
  _NoneStat    = $0010;
  _HoldStat    = $0020;
  _CrashStat   = $0040;
  _Mandatory   = $0080;

const
  TagLength  = 40;  // Maximum length of a fileecho tag
  ExportSize = 255; // Size of the systems list

type
  FileEchoTagSTr = String[TagLength];

  NetAddress = Packed Record
    Zone, Net, Node, Point : smallword;
  end;

  ExportEntry = Packed Record
    Address: NetAddress;
    Status : byte;
  end;

  ExportArray = packed Array[1..ExportSize] of ExportEntry; { Systems list                                     }

  // FAREAS.FIX
  FileMGRrec = packed Record
    Name      : FileEchoTagStr;
    Message   : String[12];
    Comment   : String[55];
    Group     : Byte;
    Attrib    : smallword;
    KeepLate  : Byte;
    Convert   : Byte;
    UplinkNum : Byte;
    DestDir   : String[60];
    TotalFiles,
    TotalKb   : smallword;
    Byear,
    Bmonth    : Byte;
    _FBoard   : smallWord;
    UseAka    : Byte;
    LongDesc  : Byte;
    Banner    : String[8];
    UnitCost     : packed array [1..6] of Byte; // Real
    UnitSize     : byte;
    DivCost      : byte;
    AddPercentage: packed array [1..6] of Byte; // Real
    IncludeRcost : Byte;
    Attrib2      : smallword;
    PurgeSize,
    PurgeNum,
    PurgeAge     : smallword;
    BBSmask      : smallword;
    Extra        : packed array[1..19] of byte;
    Export       : ExportArray;
  end;

  // FAREAS.IDX
  FileMGRidx = Record
    Name   : FileEchoTagStr;
    Group  : Byte;
    Offset : smallword;
  end;


var
  S: String;
  A: TAddress;
  P: PAddress;
  n: Integer;
  j: Integer;

  DataStream : TBufStream;
  IndexStream: TBufStream;
  DataRec    : FileMgrRec;
  IndexRec   : FileMgrIdx;

  Echo : PFileEcho;
  Area : PFileArea;

  Info : record
           Created: Integer;
           Reused : Integer;
         end;

begin
  S := '*.Fix';
  if not ExecFileOpenDlg(LoadString(_SImportAllFixCaption), S, S) then Exit;

  DataStream.Init( S, stOpenRead, STREAM_BUFFER_SIZE );
  if DataStream.Status <> stOk then
  begin
    DataStream.Done;
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  S := ChangeFileExt( S, '.Idx' );

  IndexStream.Init( S, stOpenRead, STREAM_BUFFER_SIZE );
  if IndexStream.Status <> stOk then
  begin
    IndexStream.Done;
    DataStream.Done;
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  OpenWorking( Format(LoadString(_SImportingAllfix), [S]) );
  OpenProgress( IndexStream.GetSize );
  Log^.Write( ll_Service, Format(LoadString(_SImportingAllfix), [S]) );
  FillChar( Info, SizeOf(Info), 0 );

  try
    FileBase^.Modified := True;
    IndexStream.Read( IndexRec, SizeOf(FileMgrIdx) );
    while IndexStream.Status = stOk do
    begin
      UpdateProgress( IndexStream.GetPos );
      DataStream.Seek( IndexRec.Offset * SizeOf(FileMgrRec) );
      DataStream.Read( DataRec, SizeOf(FileMgrRec) );

      Echo := FileBase^.GetEcho( DataRec.Name );
      if Echo <> nil then
      begin
        Log^.Write( ll_Warning, Format(LoadString(_SLogJustAddLinks), [DataRec.Name] ));
        Inc( Info.Reused );
      end
      else
      begin
        Log^.Write( ll_Protocol, Format(LoadString(_SLogEchoCreated), [DataRec.Name] ));
        Inc( Info.Created );
        Echo := New( PFileEcho, Init( DataRec.Name ) );
        if TestBit( DataRec.Attrib, _passthru ) then
        begin
          Echo^.Area := nil;
          Log^.Write( ll_Expand, LoadString(_SLogPassthrough) );
        end
        else
        begin
          Log^.Write( ll_Expand, Format(LoadString(_SLogParking), [DataRec.DestDir]));
          Area := FileBase^.GetAreaByPath( DataRec.Name );
          if Area = nil then
          begin
            Area := New( PFileArea, Init( 'FileEcho: ' + DataRec.Name ) );
            Log^.Write( ll_Protocol, Format(LoadString(_SLogNewHostCreated), [Area^.Name^]));
            Area^.DL_Path^.Insert( AllocStr( DataRec.DestDir ) );
            ReplaceStr( Area^.FilesBbs, AtPath( FILES_BBS, DataRec.DestDir ) );
            ReplaceStr( Area^.Group, FILE_ECHO_GROUP );
            FileBase^.Insert( Area );
            if not DirExists( DataRec.DestDir ) and not CreateDirTree( DataRec.DestDir ) then
              Log^.Write( ll_Warning, Format(LoadString(_SMkDirFailed), [DataRec.DestDir] ));
          end;
          Echo^.Area := Area;
        end;
        FileBase^.EchoList^.Insert( Echo );
      end;
      for n := 1 to ExportSize do
      begin
        with DataRec.Export[n], Address do
        begin
          if Zone = 0 then Break;

          A.Zone  := Zone;
          A.Net   := Net;
          A.Node  := Node;
          A.Point := Point;

          if TestBit( Status, _SendTo ) and not Echo^.Downlinks^.Search( @A, j ) then
            Echo^.Downlinks^.AtInsert( j, NewAddr(A) );

          if TestBit( Status, _ReceiveFrom ) and not Echo^.Uplinks^.Search( @A, j ) then
            Echo^.Uplinks^.AtInsert( j, NewAddr(A) );
        end;
      end;
      IndexStream.Read( IndexRec, SizeOf(FileMgrIdx) );
    end;
  finally
    IndexStream.Done;
    DataStream.Done;
    CloseWorking;
  end;

  MessageBox( Format(LoadString(_SImportEchoSummary), [Info.Created, Info.Reused]), nil, mfInformation + mfOkButton );
end; { Import_Allfix }

{ --------------------------------------------------------- }
{ Import_DMTic                                              }
{ --------------------------------------------------------- }

procedure Import_DMTic;
var
  S: String;
  A: TAddress;
  N: Integer;
  j: Integer;
  Map  : TMappedFile;
  Echo : PFileEcho;
  Area : PFileArea;
  Key  : String;
  Value: String;
  EchoTag : String;
  EchoDir : String;
  Access  : (_ReadOnly, _WriteOnly, _ReadWrite);
  Info : record
           Created: Integer;
           Reused : Integer;
         end;
begin
  S := '*.Ini';
  if not ExecFileOpenDlg(LoadString(_SImportDMCaption), S, S) then Exit;

  if not FileExists( S ) then
  begin
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  OpenWorking( Format(LoadString(_SImportingDMT), [S])  );
  Log^.Write( ll_Service, Format(LoadString(_SImportingDMT), [S]) );
  try
    Map.Init( S );
    OpenProgress( Map.GetSize );
    Echo := nil;
    FillChar( Info, SizeOf(Info), 0 );
    while Map.GetLine( S ) do
    begin
      UpdateProgress( Map.GetPos );
      StripComment( S );
      if S = '' then Continue;
      SplitPair( S, Key, Value );
      if JustSameText( Key, 'Area' ) then
      begin
        N := WordCount( Value, BLANK );
        if (N <> 6) and (N <> 7) then
        begin
          Log^.Write( ll_Warning, LoadString(_SBadLineIgnored) );
          Echo := nil;
          Continue;
        end;
        FileBase^.Modified := True;
        EchoTag := ExtractWord( 1, Value, BLANK );
        EchoDir := ExtractWord( 2, Value, BLANK );

        S := JustUpperCase(ExtractWord( 7, Value, BLANK ));

        // Flags:
        // P - Passthrough
        // M - "Magic" disabled
        // R - "Replaces" disabled
        // U - Mandatory
        // D - Dont extract file_id.diz

        Echo := FileBase^.GetEcho( EchoTag );
        if Echo <> nil then
        begin
          Log^.Write( ll_Warning, Format(LoadString(_SLogJustAddLinks), [EchoTag] ));
          Inc( Info.Reused );
        end
        else
        begin
          Log^.Write( ll_Protocol, Format(LoadString(_SLogEchoCreated), [EchoTag] ));
          Inc( Info.Created );
          Echo := New( PFileEcho, Init( EchoTag ) );
          if Pos('P', S) <> 0 then
            Log^.Write( ll_Expand, LoadString(_SLogPassthrough) )
          else
          begin
            Log^.Write( ll_Expand, Format(LoadString(_SLogParking), [EchoDir]));
            Area := FileBase^.GetAreaByPath( EchoDir );
            if Area = nil then
            begin
              Area := New( PFileArea, Init( 'FileEcho: ' + EchoTag ) );
              Log^.Write( ll_Protocol, Format(LoadString(_SLogNewHostCreated), [Area^.Name^]));
              Area^.DL_Path^.Insert( AllocStr( EchoDir ) );
              ReplaceStr( Area^.FilesBbs, AtPath( FILES_BBS, EchoDir ) );
              ReplaceStr( Area^.Group, FILE_ECHO_GROUP );
              FileBase^.Insert( Area );
              if not DirExists( EchoDir ) and not CreateDirTree( EchoDir ) then
                Log^.Write( ll_Warning, Format(LoadString(_SMkDirFailed), [EchoDir] ));
            end;
            Echo^.Area := Area;
          end;

          if Pos('R', S) <> 0 then
            SetBit( Echo^.Paranoia, bSkipRepl, True );

          FileBase^.EchoList^.Insert( Echo );
        end;
      end
      else if (Echo = nil) or JustSameText(Key, 'Desc') then
        Continue
      else if JustSameText( Key, 'Links' ) then
      begin
        for j := 1 to WordCount( Value, BLANK ) do
        begin
          S := ExtractWord( j, Value, BLANK );
          case S[1] of
            '!': begin
                   System.Delete(S, 1, 1);
                   Access := _ReadOnly;
                 end;
            '~': begin
                   System.Delete(S, 1, 1);
                   Access := _WriteOnly;
                 end;
            else
              Access := _ReadWrite;
          end;
          if not SafeAddr(S, A) then
          begin
            Log^.Write( ll_Warning, Format(LoadString(_SBadAddr), [S] ));
            Continue;
          end;
          if Access <> _ReadOnly then
            Echo^.UpLinks^.Insert( NewAddr(A) );
          if Access <> _WriteOnly then
            Echo^.DownLinks^.Insert( NewAddr(A) );
        end;
      end
      else
        Log^.Write( ll_Warning, Format(LoadString(_SBadLineIgnored), [S] ))
    end;
  finally
    Map.Done;
    CloseWorking;
  end;
  MessageBox( Format(LoadString(_SImportEchoSummary), [Info.Created, Info.Reused]), nil, mfInformation + mfOkButton );
end; { Import_DMTic}


{ --------------------------------------------------------- }
{ ImportEcho                                                }
{ --------------------------------------------------------- }

function ImportEcho: Boolean;
const
  bHiFiles    = 0;
  bAllFixBin  = 1;
  bDMTic      = 2;
  bTFix       = 3;
  bFilin      = 4;
var
  D: PDialog;
  Data: Longint;
begin
  Result := False;
  D := PDialog( Res^.Get('IMP_ECHO') );
  D^.HelpCtx := hcImportEchoes;
  Data := bHiFiles;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    case Data of
      bHiFiles    : Import_HiFiles;
      bAllFixBin  : Import_AllFixBin;
      bDMTic      : Import_DMTic;
    else
      MessageBox( 'Under construction ;-)', nil, mfInformation + mfOkButton );
    end;
    Result := True;
  end;
  if Log^.HasWarnings then
    ShowLog;
end; { ImportEcho }

{ --------------------------------------------------------- }
{ Import_AllfixLinks                                        }
{ --------------------------------------------------------- }

procedure Import_AllfixLinks;

const
  _stat_none         = 0;
  _stat_hold         = 1;
  _stat_crash        = 2;
  _stat_direct       = 3;
  _stat_hold_direct  = 4;
  _stat_crash_direct = 5;

type
  NetAddress = Packed Record
    Zone, Net, Node, Point : smallword;
  end;

  // Array used to store groups
  GroupArray = Array[0..31] of byte;

  // NODEFILE.FIX
  NodeMGRrec = Packed Record
    Aka           : NetAddress;
    Sysop         : String[35];
    Password      : String[20];
    Groups        : GroupArray;
    Reserved      : Byte;
    Inactive      : Boolean;
    RepNewEchos   : Boolean;
    CopyOther     : Boolean;
    SendTicWFreq  : Boolean;
    FileStat      : Byte;
    AreaMgrStat   : Byte;
    TicFile       : Byte;
    UseAka        : Byte;
    Message       : Boolean;
    Notify        : Boolean;
    Archiver      : Byte;
    Forward       : Boolean;
    AutoAdd       : Boolean;
    MgrPassword   : String[20];
    Remote        : Boolean;
    PackMode      : Byte;
    ViaNode       : NetAddress;
    Billing       : Byte;
    BillGroups    : GroupArray;
    Credit,
    WarnLevel,
    StopLevel     : array [1..6] of Byte; // Real
    SendBill      : byte;
    SendDay       : byte;
    AddPercentage : array [1..6] of Byte; // Real
    BillSent      : smallword;
    SystemPath    : String[60];
    MembershipFee : array [1..6] of Byte; // Real
    Extra2        : array[1..118] of byte;
  end;

  // NODEFILE.IDX
  NodeMGRidx = Record
    Aka   : NetAddress;
    Offset: smallword;
  end;

var
  IndexStream: TBufStream;
  DataStream : TBufStream;

  IndexRec: NodeMgrIdx;
  DataRec : NodeMgrRec;

  S: String;
  A: TAddress;

  Link : PEchoLink;
  Info : record
           Accepted: Integer;
           Rejected: Integer;
         end;

begin
  S := '*.fix';
  if not ExecFileOpenDlg(LoadString(_SImpLnkAfixCaption), S, S) then Exit;

  DataStream.Init( S, stOpenRead, STREAM_BUFFER_SIZE );
  if DataStream.Status <> stOk then
  begin
    DataStream.Done;
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  S := ChangeFileExt( S, '.Idx' );

  IndexStream.Init( S, stOpenRead, STREAM_BUFFER_SIZE );
  if IndexStream.Status <> stOk then
  begin
    IndexStream.Done;
    DataStream.Done;
    ShowError( Format(LoadString(_SFileNotFound), [S]) );
    Exit;
  end;

  OpenWorking( LoadString(_SImportingAfixLnk) );
  OpenProgress( IndexStream.GetSize );
  Log^.Write( ll_Service, Format(LoadString(_SImportingAllfix), [S]) );
  FillChar( Info, SizeOf(Info), 0 );

  try
    IndexStream.Read( IndexRec, SizeOf(NodeMGRidx) );
    while IndexStream.Status = stOk do
    begin
      UpdateProgress( IndexStream.GetPos );
      DataStream.Seek( IndexRec.Offset * SizeOf(NodeMgrRec) );
      DataStream.Read( DataRec, SizeOf(NodeMgrRec) );

      with DataRec.Aka do
      begin
        A.Zone  := Zone;
        A.Net   := Net;
        A.Node  := Node;
        A.Point := Point;
      end;

      Link := CFG^.Links^.Find( A );
      if Link = nil then
      begin
        Inc( Info.Accepted );
        Log^.Write( ll_Protocol, Format( LoadString(_SLogAddLink), [AddrToStr(A), DataRec.Sysop] ));
        New( Link, Init(A) );
        ReplaceStr( Link^.Password, DataRec.Password );
        if DataRec.RepNewEchos or DataRec.Notify then
          Include( Link^.Opt, elo_Notify );
        if DataRec.AutoAdd then
          Include( Link^.Opt, elo_AutoCreate );

        case DataRec.FileStat of
          _stat_hold         : Link^.Flavor := fl_Hold;
          _stat_crash        : Link^.Flavor := fl_Crash;
          _stat_direct       : Link^.Flavor := fl_Dir;
          _stat_hold_direct  : Link^.Flavor := fl_Hold;
          _stat_crash_direct : Link^.Flavor := fl_Dir;
        else
          Link^.Flavor := fl_Hold;
        end;
        CFG^.Links^.Insert( Link );
        CFG^.Modified := True;
      end
      else
        Inc( Info.Rejected );

       IndexStream.Read( IndexRec, SizeOf(NodeMGRidx) );
    end;
  finally
    IndexStream.Done;
    DataStream.Done;
    CloseWorking;
  end;

  MessageBox( Format(LoadString(_SImportLinkSummary), [Info.Accepted, Info.Rejected]), nil, mfInformation + mfOkButton );
end; { Import_AllfixLinks }

{ --------------------------------------------------------- }
{ ImportLinks                                               }
{ --------------------------------------------------------- }

function ImportLinks: Boolean;
const
  bAllfix = 0;
var
  D: PDialog;
  Data: Longint;
begin
  Result := False;
  D := PDialog( Res^.Get('IMP_LINKS') );
  D^.HelpCtx := hcImportLinks;
  Data := bAllFix;
  if Application^.ExecuteDialog( D, @Data ) = cmOk then
  begin
    case Data of
      bAllfix: Import_AllfixLinks;
    else
      MessageBox( 'Under construction ;-)', nil, mfInformation + mfOkButton );
    end;
    Result := True;
  end;
  if Log^.HasWarnings then
    ShowLog;
end; { ImportLinks }


end.


