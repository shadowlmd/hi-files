unit UnRAR;

// ##############################################
//
// Интерфейс к UnRAR.DLL для Hi-Files 2.00
//             Virtual Pascal 2.1
// ---------------------------------------
//   Copyright (C) 2002 Leemon [2:461/79]
//
// ##############################################

interface

uses Windows;

const
  ERAR_END_ARCHIVE    = 10;
  ERAR_NO_MEMORY      = 11;
  ERAR_BAD_DATA       = 12;
  ERAR_BAD_ARCHIVE    = 13;
  ERAR_UNKNOWN_FORMAT = 14;
  ERAR_EOPEN          = 15;
  ERAR_ECREATE        = 16;
  ERAR_ECLOSE         = 17;
  ERAR_EREAD          = 18;
  ERAR_EWRITE         = 19;
  ERAR_SMALL_BUF      = 20;

  RAR_OM_LIST         =  0;
  RAR_OM_EXTRACT      =  1;

  RAR_SKIP            =  0;
  RAR_TEST            =  1;
  RAR_EXTRACT         =  2;

  RAR_VOL_ASK         =  0;
  RAR_VOL_NOTIFY      =  1;

  RAR_DLL_VERSION     =  2;

  UCM_CHANGEVOLUME    =  0;
  UCM_PROCESSDATA     =  1;
  UCM_NEEDPASSWORD    =  2;

type
  RARHeaderData = record
    ArcName,
    FileName: array[0..Pred(260)] of Char;
    Flags,
    PackSize,
    UnpSize,
    HostOS,
    FileCRC,
    FileTime,
    UnpVer,
    Method,
    FileAttr: UINT;
    CmtBuf: PChar;
    CmtBufSize,
    CmtSize,
    CmtState: UINT;
  end;

  RAROpenArchiveData = record
    ArcName: PChar;
    OpenMode,
    OpenResult: UINT;
    CmtBuf: PChar;
    CmtBufSize,
    CmtSize,
    CmtState: UINT;
  end;

type
{&StdCall+}
  TRAROpenArchive  = function ( var AD: RAROpenArchiveData ) : THandle;
  TRARCloseArchive = function ( hArcData: THandle ) : Integer;
  TRARReadHeader   = function ( hArcData: THandle; var HD: RARHeaderData ) : Integer;
  TRARProcessFile  = function ( hArcData: THandle; Op: Integer; DPath, DName: PChar ) : Integer;
{&StdCall-}

var
  RAROpenArchive : TRAROpenArchive;
  RARCloseArchive: TRARCloseArchive;
  RARReadHeader  : TRARReadHeader;
  RARProcessFile : TRARProcessFile;

const
  UnrarDLL: THandle = 0;

function UnrarLoaded: Boolean;
procedure UnloadUnrar;

{ =================================================================== }

implementation

uses _Log;

{ --------------------------------------------------------- }
{ UnrarLoaded                                               }
{ --------------------------------------------------------- }

function UnrarLoaded: Boolean;
begin
  if UnrarDLL <> 0 then
  begin
    Result := True;
    Exit;
  end;
  UnrarDLL := LoadLibrary( 'unrar.dll' );
  if UnrarDLL = 0 then
  begin
    Result := False;
    Exit;
  end;

  @RAROpenArchive  := GetProcAddress( UnrarDLL, 'RAROpenArchive' );
  @RARCloseArchive := GetProcAddress( UnrarDLL, 'RARCloseArchive' );
  @RARReadHeader   := GetProcAddress( UnrarDLL, 'RARReadHeader' );
  @RARProcessFile  := GetProcAddress( UnrarDLL, 'RARProcessFile' );

  Log^.Write( ll_Service, 'Обнаружен UNRAR.DLL, линкуемся...' );
  Result := True;
end; { UnrarLoaded }


{ --------------------------------------------------------- }
{ UnloadUnrar                                               }
{ --------------------------------------------------------- }

procedure UnloadUnrar;
begin
  if UnrarDLL <> 0 then
  begin
    FreeLibrary( UnrarDLL );
    UnrarDLL := 0;
  end;
end; { UnloadUnrar }

end.

