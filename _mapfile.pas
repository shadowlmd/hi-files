unit _MapFile;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

{$DEFINE MAPFILE_BUFFER}

interface

uses
  Objects
{$IFDEF MAPFILE_WINAPI}
  , Windows
{$ENDIF}
  ;

{$IFDEF MAPFILE_TEXT}

type
  PMappedFile = ^TMappedFile;
  TMappedFile = object (TObject)
    LineNo: Integer;
    constructor Init( const FileName: String );
    destructor Done; virtual;
    function GetLine( var S: String ) : Boolean;
  private
    F: Text;
    Open: Boolean;
  end; { TMappedFile }

{$ENDIF}

{$IFDEF MAPFILE_BUFFER}

type
  PMappedFile = ^TMappedFile;
  TMappedFile = object (TObject)
    LineNo : Integer;
    constructor Init( const FileName: String );
    constructor Mirror( Image: PChar; ImageSize: Integer );
    destructor Done; virtual;
    function GetLine( var S: String ) : Boolean;
    function GetSize: Integer;
    function GetPos: Integer;
  private
    Buffer : PChar;
    BufPtr : Integer;
    BufSize: Integer;
  end; { TMappedFile }

{$ENDIF}

{$IFDEF MAPFILE_WINAPI}

type
  PMappedFile = ^TMappedFile;
  TMappedFile = object (TObject)
    LineNo: Integer;
    constructor Init( FileName: String );
    destructor Done; virtual;
    function GetLine( var S: String ) : Boolean;
    function GetSize: Integer;
    function GetPos: Integer;
  private
    Buffer  : PChar;
    BufPtr  : Integer;
    BufSize : Integer;
    hFile   : THandle;
    hMapping: THandle;
  end; { TMappedFile }

{$ENDIF}

{ =================================================================== }

implementation

{$IFDEF MAPFILE_TEXT}

{ --------------------------------------------------------- }
{ TMappedFile                                               }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TMappedFile.Init( const FileName: String );
begin
  inherited Init;
  Assign( F, FileName );
  Reset( F );
  Open := True;
end; { Init }

{ Done ---------------------------------------------------- }

destructor TMappedFile.Done;
begin
  if Open then
    Close( F );
  inherited Done;
end; { Done }

{ GetLine ------------------------------------------------- }

function TMappedFile.GetLine( var S: String ) : Boolean;
begin
  S := '';
  Result := False;
  if Open then
  begin
    if Eof( F ) then Exit;
    Readln( F, S );
    Result := True;
  end
  else
    Result := False;
end; { GetLine }

{$ENDIF}


{$IFDEF MAPFILE_BUFFER}

uses MyLib, SysUtils, App;

{ --------------------------------------------------------- }
{ TMappedFile                                               }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TMappedFile.Init( const FileName: String );
var
  S: TBufStream;
begin
  inherited Init;
  S.Init( FileName, stOpenRead, 2048 );
  if S.Status <> stOk then
  begin
    S.Done;
    Exit;
  end;
  BufSize := S.GetSize;
  if BufSize > 0 then
  begin
    GetMem( Buffer, BufSize );
    if Buffer = nil then
      OutOfMemoryError;
    S.Read( Buffer^, BufSize );
  end
  else
    Buffer := nil;
  S.Done;
  BufPtr := 0;
  LineNo := 0;
end; { Init }

{ Mirror -------------------------------------------------- }

constructor TMappedFile.Mirror( Image: PChar; ImageSize: Integer );
begin
  inherited Init;
  Buffer  := Image;
  BufSize := ImageSize;
  BufPtr  := 0;
  LineNo  := 0;
end; { Mirror }

{ Done ---------------------------------------------------- }

destructor TMappedFile.Done;
begin
  if Buffer <> nil then FreeMem( Buffer );
  inherited Done;
end; { Done }

{ GetLine ------------------------------------------------- }

function TMappedFile.GetLine( var S: String ) : Boolean;
var
  j: Integer;
  n: Integer;
begin
  Result := False;
  if BufPtr >= BufSize then Exit;
  j := ScanR( Buffer[0], BufPtr, BufSize, #10 );
  n := j - BufPtr;
  if (j > 0) and (Buffer[j-1] = #13) then Dec(n);
  if n > 255 then n := 255;
  S[0] := Char(n);
  Move( Buffer[BufPtr], S[1], n );
  BufPtr := j + 1;
  Inc( LineNo );
  Result := True;
end; { GetLine }

{ GetSize ------------------------------------------------- }

function TMappedFile.GetSize: Integer;
begin
  Result := BufSize;
end; { GetSize }

{ GetPos -------------------------------------------------- }

function TMappedFile.GetPos: Integer;
begin
  Result := BufPtr;
end; { GetPos }

{$ENDIF}

{$IFDEF MAPFILE_WINAPI}

uses SysUtils, MyLib;

{ --------------------------------------------------------- }
{ TMappedFile                                               }
{ --------------------------------------------------------- }

{ Init ---------------------------------------------------- }

constructor TMappedFile.Init( FileName: String );
begin
  inherited Init;
  FileName[Succ(Length(FileName))] := #0;
  hFile := CreateFile( @FileName[1], GENERIC_READ, FILE_SHARE_READ,
                       nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0 );
  if hFile = 0 then
    raise EInOutError.Create( 'Could not open the file "' + FileName + '"' );

  hMapping := CreateFileMapping( hFile, nil, PAGE_READONLY, 0, 0, nil );

  if hMapping = 0 then
  begin
    CloseHandle( hFile );
    raise EInOutError.Create( 'CreateFileMapping error, file: "' + FileName + '"' );
  end;

  Buffer := MapViewOfFile( hMapping, FILE_MAP_READ, 0, 0, 0 );

  if Buffer = nil then
  begin
    CloseHandle( hMapping );
    CloseHandle( hFile );
    raise EInOutError.Create( 'MapViewOfFile error, file: "' + FileName + '"' );
  end;

  BufSize := GetFileSize( hFile, nil );
  BufPtr  := 0;

end; { Init }

{ Done ---------------------------------------------------- }

destructor TMappedFile.Done;
begin
  UnmapViewOfFile( Buffer );
  CloseHandle( hMapping );
  CloseHandle( hFile );
  inherited Done;
end; { Done }

{ GetLine ------------------------------------------------- }

function TMappedFile.GetLine( var S: String ) : Boolean;
var
  j: Integer;
  n: Integer;
begin
  Result := False;
  if BufPtr >= BufSize then Exit;
  j := ScanR( Buffer[0], BufPtr, BufSize, #13 );
  n := j - BufPtr;
  if n > 255 then n := 255;
  S[0] := Char(n);
  Move( Buffer[BufPtr], S[1], n );
  BufPtr := j + 1;
  if (BufPtr < BufSize) and (Buffer[BufPtr] = #10) then Inc(BufPtr);
  Inc( LineNo );
  Result := True;
end; { GetLine }

{ GetSize ------------------------------------------------- }

function TMappedFile.GetSize: Integer;
begin
  Result := BufSize;
end; { GetSize }

{ GetPos -------------------------------------------------- }

function TMappedFile.GetPos: Integer;
begin
  Result := BufPtr;
end; { GetPos }

{$ENDIF}

end.

