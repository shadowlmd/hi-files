unit UnZip;

// ##############################################
//
// Интерфейс к UnZIP.DLL для Hi-Files 2.00
//             Virtual Pascal 2.1
// ---------------------------------------
//   Copyright (C) 2002 Leemon [2:461/79]
//
// ##############################################

interface

uses Windows;

type
  TZipRec = record
    Internal     : array [0..11] of Byte;
    Time,
    Size,
    CompressSize,
    Offset,
    CRC          : Longint;
    FileName     : array [0..259] of Char;
    PackMethod,
    Attr,
    Flags        : SmallWord;     { used internally: do not access directly! }
  end; { TZipRec }

{&StdCall+}
  TGetFirstInZip = function( zipfilename : pchar;VAR zprec : tZipRec ) : integer;
  TGetNextInZip  = function( VAR Zprec : tZiprec ) : integer;
  TCloseZipFile  = procedure( VAR Zprec : tZiprec );
  TUnzipFile     = function( SourceZipFile, OutBuffer : pChar;
                   var BufSize: Longint; Offset: Longint;
                   hFileAction: hWnd; cm_index: Integer ) : Integer;
{&StdCall-}

var
  GetFirstInZip: TGetFirstInZip;
  GetNextInZip : TGetNextInZip;
  CloseZipFile : TCloseZipFile;
  UnzipFile    : TUnzipFile;

const
  unzip_Ok             =  0;
  unzip_CRCErr         = - 1;
  unzip_WriteErr       = - 2;
  unzip_ReadErr        = - 3;
  unzip_ZipFileErr     = - 4;
  unzip_UserAbort      = - 5;
  unzip_NotSupported   = - 6;
  unzip_Encrypted      = - 7;
  unzip_InUse          = - 8;
  unzip_InternalError  = - 9;    {Error in zip format}
  unzip_NoMoreItems    = - 10;
  unzip_FileError      = - 11;   {Error Accessing file}
  unzip_NotZipfile     = - 12;   {not a zip file}
  unzip_HeaderTooLarge = - 13;   {can't handle such a big ZIP header}
  unzip_ZipFileOpenError = - 14; { can't open zip file }
  unzip_SeriousError   = - 100;  {serious error}
  unzip_MissingParameter = - 500; {missing parameter}

const
  UnzipDLL: THandle = 0;

function UnzipLoaded: Boolean;
procedure UnloadUnzip;

{ =================================================================== }

implementation

uses _LOG;

{ --------------------------------------------------------- }
{ UnzipLoaded                                               }
{ --------------------------------------------------------- }

function UnzipLoaded: Boolean;
begin
  Result := True;
  if UnzipDLL <> 0 then
    Exit;
  UnzipDLL := LoadLibrary( 'unzip.dll' );
  if UnzipDLL = 0 then
  begin
    Result := False;
    Exit;
  end;

  @GetFirstInZip := GetProcAddress( UnzipDLL, 'GetFirstInZip' );
  @GetNextInZip  := GetProcAddress( UnzipDLL, 'GetNextInZip' );
  @CloseZipFile  := GetProcAddress( UnzipDLL, 'CloseZipFile' );
  @UnzipFile     := GetProcAddress( UnzipDLL, 'unzipfiletomemory' );

  Log^.Write( ll_Service, 'Обнаружен UNZIP.DLL, линкуемся...' );
end; { UnzipLoaded }

{ --------------------------------------------------------- }
{ UnloadUnzip                                               }
{ --------------------------------------------------------- }

procedure UnloadUnzip;
begin
  if UnzipDLL <> 0 then
  begin
    FreeLibrary( UnzipDLL );
    UnzipDLL := 0;
  end;
end; { UnloadUnzip }

end.




