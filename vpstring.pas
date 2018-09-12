unit vpstring;

interface

{$H-} // Short string functions
{&Delphi+}

// ExtractFirst extracts the first substring up to, but not including
// the first occurrence of _Sep.  The _S parameter is modified to
// have this part of the string removed and _First contains the substring.
// The function returns False if _S is empty.
function ExtractFirst(var _S: ShortString; var _First: ShortString; _Delimiter: Char): Boolean;

// LeftStr is short for "Copy( _s, 1, _Len )"
function LeftStr( const _S: String; _Len: Integer ): String;

// RightStr is short for "Copy( _s, 1, Pos(_Separator, _s)-1)"
function RightStr( const _s: string; _Len: integer ): string;

// TailStr is short for "Copy( _s, _Start, Length( _s ) - _Start +1 )"
function TailStr( const _S: String; _Start: Integer ): String;

// Ensure path has trailing slash (unless blank)
function EnsureSlash( const _Path: String ): String;

implementation

uses
  VpSysLow;

function ExtractFirst(var _S: ShortString; var _First: ShortString; _Delimiter: Char): Boolean;
var
  p: integer;
begin
  Result := _S <> '';
  if Result then
    begin
      p := Pos(_Delimiter, _S);
      if p <> 0 then
        begin
          _First := LeftStr(_S, p-1);
          _S := TailStr(_S, p+1);
        end
      else
        begin
          _First := _S;
          _S := '';
        end;
    end;
end;

function RightStr( const _s: string; _Len: integer ): String;
begin
  Result := Copy( _s, Length( _s )- _Len + 1, _Len );
end;

function LeftStr( const _s: String; _Len: Integer): String;
begin
  Result := Copy( _s, 1, _Len );
end;

function TailStr( const _s: string; _Start: integer ): string;
begin
  Result := Copy( _s, _Start, Length( _s ) - _Start +1 );
end;

function EnsureSlash( const _Path: String ): String;
begin
  if (_Path <> '') and (_Path[Length(_Path)] <> SysPathSep) then
    Result := _Path + SysPathSep
  else
    Result := _Path;
end;

end.
