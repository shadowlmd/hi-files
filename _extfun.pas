function F_Pad( S: String; N: Longint ) : String; far;
begin
  F_Pad := Pad( S, N );
end; { F_Pad }

function F_PadCh( S: String; N: Longint; Ch: String ) : String; far;
begin
  F_PadCh := PadCh( S, N, Ch[1] );
end; { F_PadCh }

function F_LeftPad( S: String; N: Longint ) : String; far;
begin
  F_LeftPad := LeftPad( S, N );
end; { F_LeftPad }

function F_LeftPadCh( S: String; N: Longint; Ch: String ) : String; far;
begin
  F_LeftPadCh := LeftPadCh( S, N, Ch[1] );
end; { F_LeftPadCh }

function F_ASRF( N: Float ) : String; far;
begin
  F_ASRF := ASRF( N );
end; { F_ASRF }

function F_IntToStr( N: Longint ) : String; far;
begin
  F_IntToStr := IntToStr( N );
end; { F_IntToStr }

function F_IntToStrZ( N, Z: Longint ) : String; far;
begin
  F_IntToStrZ := Int2StrZ( N, Z );
end; { F_IntToStrZ }

function F_Center( S: String; N: Longint ) : String; far;
begin
  F_Center := Center( S, N );
end; { F_Center }

function F_CenterCh( S: String; N: Longint; Ch: String ) : String; far;
begin
  F_CenterCh := CenterCh( S, N, Ch[1] );
end; { F_CenterCh }

function F_Random( N: Longint ) : Longint; far;
begin
  F_Random := Random( N );
end; { F_Random }

function F_Substr( S: String; From, Len: Longint ) : String; far;
begin
  F_Substr := Copy( S, From, Len );
end; { F_Substr }

function F_CharStr( S: String; Len: Longint ) : String; far;
begin
  F_CharStr := CharStr( S[1], Len );
end; { F_CharStr }

function F_Length( S: String ) : Longint; far;
begin
  F_Length := Length( S );
end; { F_Length }

function F_FileComment : String; far;
begin
  if FD <> nil then
    FD^.GetLine( Result )
  else
    Result := '';
end; { F_GoTop }

function F_Match( Source, Pattern: String ) : Boolean; far;
begin
  Result := WildMatch( Source, Pattern );
end; { F_Match }

function F_FileTime : Float; far;
begin
  Result := FileDateToDateTime( FD^.Time );
end; { F_FileTime }

function F_FormatDT( Format: String; DT: TDateTime ) : String; far;
{$IFDEF Win32}
var
  b: array [0..256] of Char;
begin
  StrPCopy( b, FormatDateTime( Format, DT ) );
  CharToOemBuff( b, b, 256 );
  Result := StrPas( b );
{$ELSE}
begin
  Result := FormatDateTime( Format, DT );
{$ENDIF}
end; { F_FormatDT }

function F_Now : Float; far;
begin
  Result := SysUtils.Now;
end; { F_Now }

function F_DescMissing: Boolean; far;
begin
  if FD <> nil then
    Result := FD^.NoComment
  else
    Result := False;
end; { F_DescMissing }

function F_Trim( S: String ) : String; far;
begin
  Result := Trim(S);
end; { F_Trim }

function F_TrimR( S: String ) : String; far;
begin
  Result := TrimRight(S);
end; { F_TrimR }

function F_TrimL( S: String ) : String; far;
begin
  Result := TrimLeft(S);
end; { F_TrimL }

function F_JustFileName( S: String ) : String; far;
begin
  Result := ExtractFileNameOnly(S);
end; { F_JustFileName }

