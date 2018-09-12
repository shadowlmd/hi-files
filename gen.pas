unit Gen;

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

procedure RunGenerator;
procedure BuildComment( FD: PFileDef; const Path: String );

{ =================================================================== }

implementation

uses
{$IFDEF WIN32}
  Windows, UnRAR, UnZIP,
{$ENDIF}
  Objects, _LOG, _CFG, SysUtils, MyLib, ArcV, Spawn, AreaPane, EchoPane,
  _Report, _Script, _CRC32, _Working, _RES, vpUtils, MsgBox, Views;


{ --------------------------------------------------------- }
{ TAnnounce                                                  }
{ --------------------------------------------------------- }

type
  PAnItem = ^TAnItem;
  TAnItem = record
    FileName: PString;
    FileDate: UnixTime;
    AreaCRC : Longint;
  end; { TAnItem }

  PAnnounce = ^TAnnounce;
  TAnnounce = object (TSortedCollection)
    Modified: Boolean;
    Version : SmallWord;
    constructor Init;
    constructor Load( var S: TStream );
    procedure Store( var S: TStream );
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    procedure FreeItem( Item: Pointer ); virtual;
    procedure PutItem( var S: TStream; Item: Pointer ); virtual;
    function GetItem( var S: TStream ) : Pointer; virtual;
    procedure Refresh;
    procedure Freshen( Area: PFileArea; FD: PFileDef );
  private
    function FindItem( FD: PFileDef; Area: PFileArea ) : PAnItem;
    function NewItem( FD: PFileDef; Area: PFileArea ) : PAnItem;
  end; { TAnnounce }

const AnnSignStr = 'HI-FILES Announce'#26;
type  TAnnSign = array [0..Length(AnnSignStr)-1] of Char;
const AnnSign : TAnnSign = AnnSignStr;

const
  ANNOUNCE_EXT = '.Ann';

var
  Announce: PAnnounce;

{ Init ---------------------------------------------------- }

constructor TAnnounce.Init;
begin
  inherited Init( 50, 50 );
end; { Init }

{ Load ---------------------------------------------------- }

constructor TAnnounce.Load( var S: TStream );
var
  Sign: TAnnSign;
begin
  try
    S.Read( Sign, SizeOf(TAnnSign) );
    if StrLComp( Sign, AnnSign, SizeOf(TAnnSign) ) <> 0 then
      raise Exception.Create( LoadString(_SBadAnFile) );
    S.Read( Version, SizeOf(SmallWord) );
    if (Version <> 3) and (Version <> 4) then
      raise Exception.Create( Format(LoadString(_SBadAnVer), [Version] ));
    inherited Load( S );
  except
    on E: Exception do
      begin
        ShowError( Format(LoadString(_SAnFailed), [E.Message] ));
        Fail;
      end;
  end;
end; { Load }

{ Store --------------------------------------------------- }

procedure TAnnounce.Store( var S: TStream );
begin
  Version := 4;
  S.Write( AnnSign, SizeOf(AnnSign) );
  S.Write( Version, SizeOf(SmallWord) );
  inherited Store( S );
end; { Store }

{ FreeItem ------------------------------------------------ }

procedure TAnnounce.FreeItem( Item: Pointer );
begin
  FreeStr( PAnItem(Item)^.FileName );
  Dispose( PAnItem(Item) );
end; { FreeItem }

{ Compare ------------------------------------------------- }

function TAnnounce.Compare( Key1, Key2: Pointer ) : Integer;
var
  A1: PAnItem absolute Key1;
  A2: PAnItem absolute Key2;
begin
  Result := JustCompareText( A1^.FileName^, A2^.FileName^ );
  if Result = 0 then
  begin
    if A1^.AreaCRC > A2^.AreaCRC then
      Result := 1
    else if A1^.AreaCRC < A2^.AreaCRC then
      Result := -1
    else
      Result := 0;
  end;
end; { Compare }

{ PutItem ------------------------------------------------- }

procedure TAnnounce.PutItem( var S: TStream; Item: Pointer );
var
  A: PAnItem absolute Item;
begin
  S.WriteStr( A^.FileName );
  S.Write( A^.FileDate, SizeOf(TAnItem) - SizeOf(PString) );
end; { PutItem }

{ GetItem ------------------------------------------------- }

function TAnnounce.GetItem( var S: TStream ) : Pointer;
var
  A: PAnItem;
  F: String[12];
begin
  New( A );

  if Version = 3 then
  begin
    S.Read( F, SizeOf(F) );
    A^.FileName := AllocStr(F);
  end
  else
    A^.FileName := S.ReadStr;

  S.Read( A^.FileDate, SizeOf(TAnItem) - SizeOf(PString) );
  Result := A;
end; { GetItem }

{ FindItem ------------------------------------------------ }

function TAnnounce.FindItem( FD: PFileDef; Area: PFileArea ) : PAnItem;
var
  A: TAnItem;
  j: Integer;
begin
  A.FileName := FD^.FileName;
  A.FileDate := FileTimeToUnix( FD^.Time );
  A.AreaCRC  := GetStrCRC( Area^.Name^ );

  if Search( @A, j ) then
    Result := At(j)
  else
    Result := nil;
end; { FindItem }

{ NewItem ------------------------------------------------- }

function TAnnounce.NewItem( FD: PFileDef; Area: PFileArea ) : PAnItem;
begin
  New( Result );
  with Result^ do
  begin
    FileName := AllocStr( FD^.FileName^ );
    FileDate := FileTimeToUnix( FD^.Time );
    AreaCRC  := GetStrCRC( Area^.Name^ );
  end;
end; { NewItem }

{ Refresh ------------------------------------------------- }

procedure TAnnounce.Refresh;
var
  j: Integer;
  Z: UnixTime;
  A: PAnItem;

  procedure RefreshArea( Area: PFileArea ); far;
  var
    FD: PFileDef;
  begin
    j := 0;
    while j < Area^.Count do
    begin
      FD := Area^.At(j);
      A := FindItem( FD, Area );
      if A = nil then
      begin
        Insert( NewItem( FD, Area ) );
        Modified := True;
        Inc(j);
      end
      else
        Area^.AtFree(j);
    end;
  end; { RefreshArea }

begin
  Log^.Write( ll_Protocol, LoadString(_SLogCheckingAn) );
  Z := CurrentUnixTime;
  j := 0;
  while j < Count do
  begin
    A := At(j);
    // ’à¥åªà â­ë© § ¯ á ­  ã¢¥«¨ç¥­¨¥ "àãçª ¬¨" NewFilesAge
    if DaysBetween( Z, A^.FileDate ) > 3 * CFG^.NewFilesAge then
    begin
      AtFree( j );
      Modified := True;
      Continue;
    end;
    Inc( j );
  end;
  FileBase^.ForEach( @RefreshArea );
  FileBase^.Clean;
end; { Refresh }

{ Freshen ------------------------------------------------- }

procedure TAnnounce.Freshen( Area: PFileArea; FD: PFileDef );
var
  A: PAnItem;
begin
  A := FindItem( FD, Area );
  if A <> nil then
  begin
    Free( A );
    Modified := True;
  end;
end; { Freshen }


{ --------------------------------------------------------- }
{ OpenAnnounce                                              }
{ --------------------------------------------------------- }

procedure OpenAnnounce;
var
  FileName: String;
  Stream  : TBufStream;
begin
  if Announce <> nil then Exit;
  FileName := ChangeFileExt( ParamStr(0), ANNOUNCE_EXT );
  if FileExists( FileName ) then
  begin
    Log^.Write( ll_Protocol, LoadString(_SOpeningAnFile) );
    Stream.Init( FileName, stOpenRead, 2048 );
    if Stream.Status <> stOk then
      Log^.Write( ll_Warning, Format(LoadString(_SCantOpenAn), [FileName] ))
    else
      Announce := New( PAnnounce, Load(Stream) );
    Stream.Done;
  end;
  if Announce = nil then
  begin
    Announce := New( PAnnounce, Init );
    Log^.Write( ll_Service, LoadString(_SLogAnCreated) );
  end;
end; { OpenAnnounce }

{ --------------------------------------------------------- }
{ CloseAnnounce                                             }
{ --------------------------------------------------------- }

procedure CloseAnnounce;
var
  FileName: String;
  Stream  : TBufStream;
begin
  if Announce <> nil then
  begin
    if Announce^.Modified then
    begin
      Log^.Write( ll_Protocol, LoadString(_SLogSavingAn) );
      FileName := ChangeFileExt( ParamStr(0), ANNOUNCE_EXT );
      Stream.Init( FileName, stCreate, 2048 );
      if Stream.Status = stOk then
        Announce^.Store( Stream )
      else
        Log^.Write( ll_Warning, Format(LoadString(_SCantCreateAn), [FileName] ));
      Stream.Done;
    end;
    Destroy( Announce );
    Announce := nil;
  end;
end; { CloseAnnounce }

{ --------------------------------------------------------- }
{ ScanArcIndex                                              }
{ --------------------------------------------------------- }

var
  DizFound: String;

procedure ScanArcIndex( const FName: String; FTime, OrigSize, PackSize: Longint ); far;
var
  N: String;
begin
  if DizFound = '' then
  begin
    N := Trim( FName );
    if CFG^.DizFiles^.Match(N) and (OrigSize > 0) then
      DizFound := N;
  end;
end; { ScanArcIndex }

{ --------------------------------------------------------- }
{ SearchDiz                                                 }
{ --------------------------------------------------------- }

function SearchDiz( const Archive: String ) : String;
begin
  DizFound := '';
  AddFileCallBack := ScanArcIndex;
  ReadArchive( Archive );
  Result := DizFound;
end; { SearchDiz }

{ --------------------------------------------------------- }
{ Excluded                                                  }
{ --------------------------------------------------------- }

function Excluded( FileName: ShortString ) : Boolean;
  function Match( Pat: PString ) : Boolean; far;
  begin
    Result := WildMatch( FileName, Pat^ );
  end;
begin
  Result := JustSameText( FileName, 'FILES.BBS' ) or
            (CFG^.Exclude^.FirstThat( @Match ) <> nil);
end; { Excluded }

{ --------------------------------------------------------- }
{ MoveComment                                               }
{ --------------------------------------------------------- }

procedure MoveComment( Source, Target: PFileDef );

  procedure DoMove( P: PString ); far;
  begin
    Target^.Insert( P );
  end; { DoMove }

begin
  Source^.ForEach( @DoMove );
  Source^.DeleteAll;
end; { MoveComment }

{ --------------------------------------------------------- }
{ BuildComment                                              }
{ --------------------------------------------------------- }

procedure BuildComment( FD: PFileDef; const Path: String );

{ TryDLL -------------------------------------------------- }

{$IFDEF WIN32}

function TryDLL: Boolean;
const
  BUFSIZE = 16 * 1024;
var
  A: THandle;
  ArcName : array [0..260] of Char;
  DestName: array [0..260] of Char;
  Buffer  : PChar;
  BufLen  : Longint;
  AD: RAROpenArchiveData;
  HD: RARHeaderData;
  RHCode: Integer;
  PFCode: Integer;
  Diz   : String;
  Zip   : TZipRec;

begin
  Result := False;
  if JustSameText( ExtractFileExt(FD^.FileName^), '.rar' ) and UnrarLoaded then
  begin
    FillChar( AD, SizeOf(AD), 0 );
    AD.ArcName  := StrPCopy( ArcName, AtPath(FD^.NativeName^, Path));
    AD.OpenMode := RAR_OM_EXTRACT;
    A := RAROpenArchive( AD );
    if AD.OpenResult <> 0 then
    begin
      Log^.Write( ll_Warning, LoadString(_SLogUnrarOpenError)  );
      Exit;
    end;
    Result := True;
    try
      repeat
        RHCode := RARReadHeader( A, HD );
        if RHCode <> 0 then Break;
        Diz := ExtractFileName( StrPas(HD.FileName) );
        if CFG^.DizFiles^.Match( Diz ) then
        begin
          Diz := AtPath( Diz, CFG^.TempDir );
          StrPCopy( DestName, Diz );
          PFCode := RARProcessFile( A, RAR_EXTRACT, nil, DestName );
          if PFCode <> 0 then
            raise Exception.Create( Format(LoadString(_SLogUnrarError), [PFCode] ));
          FD^.LoadFromFile( Diz );
          VFS_EraseFile( Diz );
          RARCloseArchive( A );
          Log^.Write( ll_Protocol, Format(LoadString(_SDizExtracted), [ExtractFilename(Diz)] ));
          Exit;
        end;
        PFCode := RARProcessFile( A, RAR_SKIP, nil, nil );
        if PFCode <> 0 then
          raise Exception.Create( Format(LoadString(_SLogUnrarError), [PFCode] ));
      until false;
      if RHCode = ERAR_BAD_DATA then
        raise Exception.Create( LoadString(_SLogUnrarHdrBroken) );
    except
      on E: Exception do
        Log^.Write( ll_Warning, E.Message );
    end;
    RARCloseArchive( A );
  end
  else if JustSameText( ExtractFileExt(FD^.FileName^), '.zip' ) and UnzipLoaded then
  begin
    StrPCopy( ArcName, AtPath(FD^.NativeName^, Path) );
    try
      RHCode := GetFirstInZip( ArcName, Zip );
      Result := RHCode = unzip_ok;
      while RHCode = unzip_ok do
      begin
        Diz := StrPas( Zip.FileName );
        if CFG^.DizFiles^.Match( Diz ) then
        begin
          CloseZipFile( Zip );
          GetMem( Buffer, BUFSIZE );
          BufLen := BUFSIZE;
          PFCode := UnzipFile( ArcName, Buffer, BufLen, Zip.Offset, 0, 0 );
          if PFCode < 0 then
            raise Exception.Create( Format(LoadString(_SLogUnrarError), [PFCode] ));
          FD^.EatBuffer( Buffer, BufLen );
          // Warning: Buffer destroyed by 'EatBuffer' procedure!
          Log^.Write( ll_Protocol, Format(LoadString(_SDizExtracted), [ExtractFilename(Diz)] ));
          Exit;
        end;
        RHCode := GetNextInZip( Zip );
      end;
    except
      on E: Exception do
        Log^.Write( ll_Warning, E.Message );
    end;
  end;
end; { TryDll }

{$ENDIF}

{ TryArchive ---------------------------------------------- }

procedure TryArchive;
var
  Arc: String;
  Exe: String;
  Par: String;
  Diz: String;
  Cur: String;
  ErrCode: Integer;
begin
  if CFG^.DizFiles^.Count < 1 then Exit;
  if not CFG^.Archivers^.GetCall( FD^.FileName^, Arc ) then Exit;
  Diz := SearchDiz( AtPath(FD^.FileName^, Path) );
  // …á«¨ ¬ £¨ï ­¨ç¥£® ­¥ ­ è« , ¯®¯à®¡ã¥¬ ¨§¢«¥çì ¯¥à¢ë© ®¯¨á â¥«ì ¨§ á¯¨áª .
  if Diz = '' then Diz := PString(CFG^.DizFiles^.At(0))^;
  Cur := GetCurrentDir;
  try
    if not SetCurrentDir( CFG^.TempDir ) then
      raise Exception.Create( Format(LoadString(_SCantSetTmpDir), [CFG^.TempDir] ));
    if FileExists( Diz ) then
    begin
      if not VFS_EraseFile( Diz ) then
        raise Exception.Create( Format(LoadString(_SCantDelTmpFile), [AtPath(Diz, CFG^.TempDir)]) );
    end;
    Log^.Write( ll_Protocol, Format(LoadString(_SRunExternal), [Arc] ));
    SplitPair( Arc, Exe, Par );
    ErrCode := Execute( Exe, Par + ' ' + AtPath(FD^.FileName^, Path) + ' ' + Diz, True );
    if ErrCode < 0 then
      raise Exception.Create( Format(LoadString(_SExtRunError), [-ErrCode] ));
    if ErrCode > 0 then
      raise Exception.Create( Format(LoadString(_SExtRunErrLevel), [ErrCode] ));
  except
    on E: Exception do
      Log^.Write( ll_Warning, E.Message );
  end;
  if FileExists( Diz ) then
  begin
    Log^.Write( ll_Protocol, Format(LoadString(_SDizExtracted), [Diz] ));
    FD^.LoadFromFile( Diz );
    VFS_EraseFile( Diz );
  end else
    Log^.Write( ll_Protocol, LoadString(_SLogNoDizInArc) );
  SetCurrentDir( Cur );
end; { TryArchive }

{ TryFetch ------------------------------------------------ }

procedure TryFetch;
var
  Exe: String;
  Diz: String;
  ErrCode: Integer;
begin
  if not CFG^.Fetches^.GetCall( FD^.FileName^, Exe ) then Exit;
  Log^.Write( ll_Protocol, Format(LoadString(_SRunExternal), [Exe] ));
  Diz := AtPath( DIZ_FILE, CFG^.TempDir );
  try
    if FileExists( Diz ) then
    begin
      if not VFS_EraseFile( Diz ) then
        raise Exception.Create( Format(LoadString(_SCantDelTmpFile), [AtPath(Diz, CFG^.TempDir)] ));
    end;
    ErrCode := Execute( Exe, AtPath( FD^.FileName^, Path ) + ' ' + Diz,  True );
    if ErrCode < 0 then
      raise Exception.Create( Format(LoadString(_SExtRunError), [-ErrCode] ));
    if ErrCode > 0 then
      raise Exception.Create( Format(LoadString(_SExtRunErrLevel), [ErrCode] ));
    if not FileExists( Diz ) then
      raise Exception.Create( LoadString(_SDizNotBuilt) );
    Log^.Write( ll_Protocol, LoadString(_SDizBuilt) );
    FD^.LoadFromFile( Diz );
  except
    on E: Exception do
      Log^.Write( ll_Warning, E.Message );
  end;
  if FileExists( Diz ) then
    VFS_EraseFile( Diz );
end; { TryFetch }

var
  DllPassed: Boolean;
  SaveCmt  : PFileDef;

begin
  SaveCmt := New( PFileDef, Init(FD^.FileName^) );

  MoveComment( FD, SaveCmt );

{$IFDEF WIN32}
  DllPassed := TryDLL;
  if FD^.NoComment then
  begin
    if not DllPassed then
{$ENDIF}
      TryArchive;
    if FD^.NoComment then
    begin
      TryFetch;
      if FD^.NoComment then
      begin
        if SaveCmt^.NoComment then
          FD^.AssignDefaultComment
        else
          MoveComment( SaveCmt, FD );
      end;
    end;
{$IFDEF WIN32}
  end;
{$ENDIF}

  Destroy( SaveCmt );

end; { BuildComment }


{ --------------------------------------------------------- }
{ ScanAreaPath                                              }
{ --------------------------------------------------------- }

procedure ScanAreaPath( Area: PFileArea; const Path: String );
var
  R : TSearchRec;
  FD: PFileDef;
  ShortName: String;
  LongName : String;
  FullName : String;
  DosError : Integer;
  FileIndex: Integer;
begin
  if (Path = '') or not DirExists(Path) then
  begin
    Log.Write( ll_warning, Format(LoadString(_SDirNotExists), [Path]) );
    Exit;
  end;

  DosError := SysUtils.FindFirst( AtPath('*.*', Path), faArchive + faReadOnly, R );
  while DosError = 0 do
  begin
    DecodeLFN( R, ShortName, LongName );
    try
      FileTimeToUnix( R.Time );
    except
      Log^.Write( ll_Warning, Format(LoadString(_SBadFileDate), [R.Name] ));
      Log^.Write( ll_Expand,  LoadString(_SDateShouldFixed) );
      R.Time := CurrentFileTime;
    end;
    if not Excluded( ShortName ) then
    try
      FullName := AtPath( R.Name, Path );
      if Area^.Search( @ShortName, FileIndex ) then
      begin
        FD := Area^.At(FileIndex);
        FD^.Time := R.Time;
        FD^.Size := R.Size;
        ReplaceStr( FD^.LongName, LongName );
        if CFG^.ForceCmt or (CFG^.UpdateCmt and FD^.NoComment) then
        begin
          Log^.Write( ll_Protocol, Format(LoadString(_SForceDiz), [R.Name] ));
          BuildComment( FD , Path );
        end;
        if (FileTimeToUnix( FD^.Time ) > Area^.LastScanTime) and
           (Area^.LastScanTime > 0) then
        begin
          Log^.Write( ll_Protocol, Format(LoadString(_SUpdatedFile), [R.Name] ));
          if not CFG^.KeepOldCmt then
            BuildComment( FD, Path );
          OpenAnnounce;
          Announce^.Freshen( Area, FD );
        end;
      end
      else if Area^.Scan then
      begin
        Log^.Write( ll_Protocol, Format(LoadString(_SNewFile), [R.Name] ));
        FD := New( PFileDef, Init(ShortName) );
        ReplaceStr( FD^.LongName, LongName );
        FD^.Time := R.Time;
        FD^.Size := R.Size;
        if CFG^.TouchNew then
        begin
          FD^.Time := CurrentFileTime;
          if not VFS_TouchFile( FullName, FD^.Time ) then
            Log^.Write( ll_Warning, Format(LoadString(_SCantSetFTime), [FullName] ));
        end;
        Area^.Insert( FD );
        BuildComment( FD, Path );
      end;
    except
      on E: Exception do
        Log^.Write( ll_Error, E.Message );
    end;
    DosError := SysUtils.FindNext( R );
  end;
  SysUtils.FindClose( R );
end; { ScanAreaPath }

{ --------------------------------------------------------- }
{ WriteLogo                                                 }
{ --------------------------------------------------------- }

procedure WriteLogo( Report: PReport );
var
  S: String;
  T: String;
begin
  S := '   ÔÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼';
  T := '[Version ' + PROG_VER +']';
  Move( T[1], S[33-Length(T)], Length(T) );
  with Report^ do
  begin
    WriteOut( '' );
    WriteOut(
'   ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·' );
    WriteOut(
'   ³ÞÛ Û ÞÛ   ÛÛ ÞÛ ÞÛ  ÞÛÛ ÞÛÛÛ   Created by Hi-Files file-list generator º' );
    WriteOut(
'   ³ÞÛÜÛ ÞÛ þ ÛÜ ÞÛ ÞÛ  ÞÛÜ ÞÛÜÜ   (C) 1997-2006 by Dmitry Liman, 2:461/79 º' );
    WriteOut(
'   ³ÞÛ Û ÞÛ   Û  ÞÛ ÞÛÛ ÞÛÜ  ÜÜÛ   °°°°°±±±±±²²²² ' + GetFileDateStr(CurrentFileTime) +
' ²²²²±±±±±°°°°° º' );
    WriteOut( S );
    WriteOut( '' );
  end;
end; { Writelogo }

{ --------------------------------------------------------- }
{ BuildTextReport                                           }
{ --------------------------------------------------------- }

procedure BuildTextReport( const ReportName, ScriptName: String );
var
  Report: PTextReport;
begin
  New( Report, Init(ReportName) );
  ExecuteScript( ScriptName, Report, nil );
  WriteLogo( Report );
  Destroy( Report );
end; { BuildTextReport }

{ --------------------------------------------------------- }
{ BuildPktReports                                           }
{ --------------------------------------------------------- }

procedure BuildPktReports;
  procedure UsePoster( Poster: PPoster ); far;
  var
    Report: PPktReport;
  begin
    Log^.Write( ll_Protocol, Format(LoadString(_SLogPostInArea), [Poster^.Area] ));
    New( Report, Init(Poster) );
    ExecuteScript( Poster^.Script, Report, Poster );
    Destroy( Report );
  end; { UsePoster }
var
  Report: PPktReport;
begin
  CFG^.Posters^.ForEach( @UsePoster );
end; { BuildPktReport }

{ --------------------------------------------------------- }
{ ExportFreq                                                }
{ --------------------------------------------------------- }

procedure ExportFreq;
var
  Report: PTextReport;

  procedure DoExport( Area: PFileArea ); far;
    procedure DoExpPath( P: PString ); far;
    begin
      Report^.WriteOut( AddBackSlash(P^) );
    end;
  begin
    if not Area^.HideFreq then
      Area^.DL_Path^.ForEach( @DoExpPath );
  end; { DoExport }

begin
  New( Report, Init(CFG^.FreqDirs) );
  WriteChangedLogo( Report );
  FileBase^.ForEach( @DoExport );
  Destroy( Report );
end; { ExportFreq }

{ --------------------------------------------------------- }
{ TBestList                                                 }
{ --------------------------------------------------------- }

type
  PBestList = ^TBestList;
  TBestList = object (TSortedCollection)
    MinDLC: Integer;
    constructor Init;
    procedure FreeItem( Item: Pointer ); virtual;
    function KeyOf( Item: Pointer ) : Pointer; virtual;
    function Compare( Key1, Key2: Pointer ) : Integer; virtual;
    procedure Taste( FD: PFileDef );
  end; { TBestList }

{ Init ---------------------------------------------------- }

constructor TBestList.Init;
begin
  inherited Init( CFG^.BestCount, 10 );
  MinDLC := 1;
  Duplicates := True;
end; { Init }

{ FreeItem ------------------------------------------------ }

procedure TBestList.FreeItem( Item: Pointer );
begin
end; { FreeItem }

{ KeyOf --------------------------------------------------- }

function TBestList.KeyOf( Item: Pointer ) : Pointer;
begin
  KeyOf := @PFileDef( Item )^.DLC;
end; { KeyOf }

{ Compare ------------------------------------------------- }

function TBestList.Compare( Key1, Key2: Pointer ) : Integer;
var
  d1: ^Integer absolute Key1;
  d2: ^Integer absolute Key2;
begin
  if d1^ > d2^ then
    Compare := -1
  else if d1^ < d2^ then
    Compare := 1
  else
    Compare := 0;
end; { Compare }

{ Taste --------------------------------------------------- }

procedure TBestList.Taste( FD: PFileDef );
begin
  if FD^.DLC >= MinDLC then
  begin
    Insert( FD );
    if Count > CFG^.BestCount then
    begin
      AtFree( Count - 1 );
      MinDLC := PFileDef( At(Count - 1) )^.DLC;
    end;
  end;
end; { Taste }

{ --------------------------------------------------------- }
{ BuildBestArea                                             }
{ --------------------------------------------------------- }

procedure BuildBestArea;
var
  Area: PFileArea;
  Best: PBestList;

  procedure ScanArea( Area: PFileArea ); far;
    procedure LookFD( FD: PFileDef ); far;
    begin
      Best^.Taste( FD );
    end; { LookFD }
  begin
    if not Area^.Virt then
      Area^.ForEach( @LookFD );
  end; { ScanArea }

  procedure GiveMe( FD: PFileDef ); far;
  begin
    Area^.Insert( FD^.Dupe );
  end; { GiveMe }

begin
  if CFG^.DlcDigs = 0 then
  begin
    ShowError( LoadString(_SBestAreaFailedNoDLC ));
    Exit;
  end;
  New( Best, Init );
  New( Area, Init('The Best Files') );
  with Area^ do
  begin
    ReplaceStr( Group, 'VIRTUAL' );
    fUseAloneCmt := Lowered;
    fSorted      := Lowered;
    Virt         := True;
  end;
  FileBase^.ForEach( @ScanArea );
  Best^.ForEach( @GiveMe );
  Destroy( Best );
  FileBase^.Insert( Area );
  FileBase^.CalcSummary;
end; { BuildBestArea }

{ --------------------------------------------------------- }
{ LeaveNewFiles                                             }
{ --------------------------------------------------------- }

procedure LeaveNewFiles;
var
  UNow: UnixTime;

  function Forgot( const FileName: String ) : Boolean;
    function Match( const Pattern: String ) : Boolean; far;
    begin
      Match := WildMatch( FileName, Pattern );
    end; { Match }
  begin
    Forgot := CFG^.Forget^.FirstThat( @Match ) <> nil;
  end; { Forgot }

  procedure RefineArea( Area: PFileArea ); far;
  var
    j : Integer;
    FD: PFileDef;
  begin
    UpdateProgress( FileBase^.IndexOf(Area) );
    j := 0;
    while j < Area^.Count do
    begin
      FD := Area^.At(j);
      if FD^.AloneCmt or FD^.Missing or Forgot( FD^.FileName^ ) or
         (DaysBetween( UNow, FileTimeToUnix(FD^.Time) ) > CFG^.NewFilesAge) then
      begin
        Area^.AtFree(j);
        Continue;
      end;
      Inc(j);
    end;
  end; { RefineArea }

var
  j: Integer;
begin
  UNow := CurrentUnixTime;
  OpenWorking( LoadString(_SLeavingNewFiles) );
  OpenProgress( FileBase^.Count );
  try
    FileBase^.ForEach( @RefineArea );
    FileBase^.Clean;
  finally
    CloseWorking;
  end;
end; { LeaveNewFiles }

{ --------------------------------------------------------- }
{ RunGenerator                                              }
{ --------------------------------------------------------- }

procedure RunGenerator;
var
  ACTION: String;

  procedure ScanArea( Area: PFileArea ); far;
    procedure ScanPath( Path: PString ); far;
    begin
      ScanAreaPath(Area, Path^);
    end;
  var
    n: Integer;
  begin
    Log^.Write( ll_Protocol, '[' + Area^.Name^ + ']' );
    UpdateProgress( FileBase^.IndexOf(Area) );
    if Area^.Loaded then
    begin
      if Area^.Recurse then
        Area^.AddTree;
      n := Area^.Count;
      Area^.DL_Path^.ForEach( @ScanPath );
      Area^.LastScanTime := CurrentUnixTime;
      FileBase^.Modified := True;
      if Area^.Count > n then
        Area^.Complete;
    end
    else
      Log^.Write( ll_Error, LoadString(_SScanFailedNoBbs) );
  end; { ScanArea }

begin
  CloseFileBaseBrowser;
  CloseFileEchoBrowser;

  ACTION := LoadString( _SLogScanningFileBase );
  Announce := nil;
  LoadFileBase;
  if Log^.HasErrors then
  begin
    if CFG^.BatchMode or (MessageBox( LoadString(_SCfmIgnoreErrors), nil, mfWarning + mfYesNoCancel ) <> cmYes) then Exit;
    Log^.Clear;
  end;
  Log^.Write( ll_Service, ACTION );
  OpenWorking( ACTION );
  OpenProgress( FileBase^.Count );
  try
    FileBase^.ForEach( @ScanArea );
  finally
    CloseWorking;
  end;
  if CFG^.DropMissing then
    FileBase^.DropMissingFiles;

  // WriteFilesBbs should be called _before_ WriteFileAreaCtl !

  FileBase^.WriteFilesBbs;

  if FileBase^.Modified then
    FileBase^.WriteFileAreaCtl;
  FileBase^.CalcSummary;

  if CFG^.FreqDirs <> '' then
  begin
    Log^.Write( ll_Service, LoadString(_SLogExportFreq) );
    ExportFreq;
  end;

  if CFG^.BuildAllList then
  begin
    if CFG^.BuildBestArea then
    begin
      Log^.Write( ll_Service, LoadString(_SLogBuildingBest) );
      BuildBestArea;
    end;
    Log^.Write( ll_Service, LoadString(_SLogBuildingAll) );
    BuildTextReport( CFG^.AllFilesList, CFG^.AllFilesScript );
  end;

  if CFG^.BuildNewList or CFG^.BuildNewRep then
  begin
    Log^.Write( ll_Service, LoadString(_SLogLeavingNew) );
    LeaveNewFiles;
    if FileBase^.Count > 0 then
    begin
      if CFG^.BuildNewList then
      begin
        Log^.Write( ll_Service, LoadString(_SLogBuildingNew) );
        BuildTextReport( CFG^.NewFilesList, CFG^.NewFilesScript );
      end;
      if CFG^.BuildNewRep then
      begin
        Log^.Write( ll_Service, LoadString(_SLogBuildingNewRep) );
        OpenAnnounce;
        Announce^.Refresh;
        if FileBase^.Count > 0 then
        begin
          BuildPktReports;
          ExitCode := EXIT_NEW_FILES_FOUND;
        end
        else
          Log^.Write( ll_Protocol, LoadString(_SLogNothingToAn) );
      end;
    end
    else
      Log^.Write( ll_Protocol, LoadString(_SLogNoNewFiles) );
  end;
  CloseAnnounce;
  CloseFileBase;
end; { RunGenerator }

end.
