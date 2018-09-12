unit Spawn;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

function Execute( const Exe, Par: String; BG: Boolean ) : Integer;

{ =================================================================== }

implementation

uses
{$IFDEF WIN32}
  Windows,
{$ENDIF}
  Dos, MyLib, SysUtils, VpUtils, VpSysLow;

{ --------------------------------------------------------- }
{ GetEnvLong                                                }
{ --------------------------------------------------------- }

function GetEnvLong( const EnvVar: PChar ): PChar;
var
  P: PChar;
  L: Word;
begin
  L := StrLen(EnvVar);
  P := SysGetEnvironment;
  while P^ <> #0 do
  begin
    if (StrLIComp(P, EnvVar, L) = 0) and (P[L] = '=') then
    begin
      Result := P + L + 1;
      Exit;
    end;
    Inc(P, StrLen(P) + 1);
  end;
  Result := nil;
end;

{ --------------------------------------------------------- }
{ SearchFile                                                }
{ --------------------------------------------------------- }

function SearchFile( const FileName: String; var FullName: String ) : Boolean;
var
  Buffer : array [0..260]  of Char;
  FNameZ : array [0..260]  of Char;
  DirList: array [0..2048] of Char;
begin
  StrPCopy( DirList, ExtractFilePath(ParamStr(0)) + ';' );
  StrCat( DirList, GetEnvLong('PATH') );
  StrPCopy( FNameZ, FileName );
{$IFDEF WIN32}
  OemToAnsi( FNameZ, FNameZ );
{$ENDIF}
  SysFileSearch( Buffer, FNameZ, @DirList );
{$IFDEF WIN32}
  AnsiToOem( Buffer, Buffer );
{$ENDIF}
  FullName := StrPas(Buffer);
  Result := Buffer[0] <> #0;
end; { SearchFile }


{ --------------------------------------------------------- }
{ Execute                                                   }
{ --------------------------------------------------------- }

function Execute( const Exe, Par: String; BG: Boolean ) : Integer;
var
  ExeName: String;
  AppName: array [0..1024] of Char;
  CmdLine: array [0..1024] of Char;
{$IFDEF WIN32}
  Flags  : Longint;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
{$ENDIF}
  Ok: Boolean;
begin
  ExeName := DefaultExtension( Exe, '.Exe' );
  if not FileExists( ExeName ) then
  begin
    if not SearchFile( ExeName, ExeName ) then
    begin
      Result := -2; // File not found
      Exit;
    end;
  end;
  StrPCopy( AppName, ExeName );
  StrPCopy( CmdLine, Par );
{$IFDEF WIN32}
  OemToAnsi( AppName, AppName );
  OemToAnsi( CmdLine, CmdLine );
  StrCat( AppName, ' ' );
  StrCat( AppName, CmdLine );
  FillChar( StartupInfo, SizeOf(StartupInfo), #0 );
  with StartupInfo do
  begin
    cb          := SizeOf(TStartupInfo);
    dwFlags     := Startf_UseShowWindow;
    if BG then
      wShowWindow := sw_ShowMinNoActive
    else
      wShowWindow := sw_ShowNormal;
    hStdInput   := SysFileStdIn;
    hStdOutput  := SysFileStdOut;
    hStdError   := SysFileStdErr;
  end;
  Flags := Normal_Priority_Class + Create_New_Console;
  Ok := CreateProcess( nil, AppName, nil, nil, False, Flags, nil, nil, StartupInfo, ProcessInfo );
  if Ok then
  begin
    WaitForSingleObject( ProcessInfo.hProcess, Infinite );
    GetExitCodeProcess( ProcessInfo.hProcess, Result );
  end
  else
    Result := - GetLastError;
{$ELSE}
  Result := SysExecute( AppName, CmdLine, nil, False, nil, 0, 0, 0 );
{$ENDIF}
end; { Execute }

end.
