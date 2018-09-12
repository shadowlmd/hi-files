unit _Locale;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

procedure ReadLocale;

{ =================================================================== }

implementation

uses
  SysUtils, vpSysLow, Windows;

{ --------------------------------------------------------- }
{ ReadLocale                                                }
{ --------------------------------------------------------- }

procedure ReadLocale;
var
  Locale: LCID;
  Buffer: array [0..260] of Char;

  function GetLocaleStr( LocaleType: Integer; Default: PChar ) : PChar;
  begin
    if GetLocaleInfo(Locale, LocaleType, Buffer, 260) <= 0 then
      StrCopy(Buffer, Default);
    Result := Buffer;
  end; { GetLocaleStr }

begin
  Locale := GetThreadLocale;

  LongDayNames[1] := GetLocaleStr( LOCALE_SDAYNAME7, 'Sunday' );
  LongDayNames[2] := GetLocaleStr( LOCALE_SDAYNAME1, 'Monday' );
  LongDayNames[3] := GetLocaleStr( LOCALE_SDAYNAME2, 'Tuesday' );
  LongDayNames[4] := GetLocaleStr( LOCALE_SDAYNAME3, 'Wednesday' );
  LongDayNames[5] := GetLocaleStr( LOCALE_SDAYNAME4, 'Thursday' );
  LongDayNames[6] := GetLocaleStr( LOCALE_SDAYNAME5, 'Friday' );
  LongDayNames[7] := GetLocaleStr( LOCALE_SDAYNAME6, 'Saturday' );

  ShortDayNames[1] := GetLocaleStr( LOCALE_SABBREVDAYNAME7, 'Sun' );
  ShortDayNames[2] := GetLocaleStr( LOCALE_SABBREVDAYNAME1, 'Mon' );
  ShortDayNames[3] := GetLocaleStr( LOCALE_SABBREVDAYNAME2, 'Tue' );
  ShortDayNames[4] := GetLocaleStr( LOCALE_SABBREVDAYNAME3, 'Wed' );
  ShortDayNames[5] := GetLocaleStr( LOCALE_SABBREVDAYNAME4, 'Thu' );
  ShortDayNames[6] := GetLocaleStr( LOCALE_SABBREVDAYNAME5, 'Fri' );
  ShortDayNames[7] := GetLocaleStr( LOCALE_SABBREVDAYNAME6, 'Sat' );

  LongMonthNames[ 1] := GetLocaleStr( LOCALE_SMONTHNAME1, 'January' );
  LongMonthNames[ 2] := GetLocaleStr( LOCALE_SMONTHNAME2, 'February' );
  LongMonthNames[ 3] := GetLocaleStr( LOCALE_SMONTHNAME2, 'March' );
  LongMonthNames[ 4] := GetLocaleStr( LOCALE_SMONTHNAME2, 'April' );
  LongMonthNames[ 5] := GetLocaleStr( LOCALE_SMONTHNAME2, 'May' );
  LongMonthNames[ 6] := GetLocaleStr( LOCALE_SMONTHNAME2, 'June' );
  LongMonthNames[ 7] := GetLocaleStr( LOCALE_SMONTHNAME2, 'July' );
  LongMonthNames[ 8] := GetLocaleStr( LOCALE_SMONTHNAME2, 'August' );
  LongMonthNames[ 9] := GetLocaleStr( LOCALE_SMONTHNAME2, 'September' );
  LongMonthNames[10] := GetLocaleStr( LOCALE_SMONTHNAME2, 'October' );
  LongMonthNames[11] := GetLocaleStr( LOCALE_SMONTHNAME2, 'November' );
  LongMonthNames[12] := GetLocaleStr( LOCALE_SMONTHNAME2, 'December' );

  ShortMonthNames[ 1] := GetLocaleStr( LOCALE_SABBREVMONTHNAME1, 'Jan' );
  ShortMonthNames[ 2] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Feb' );
  ShortMonthNames[ 3] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Mar' );
  ShortMonthNames[ 4] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Apr' );
  ShortMonthNames[ 5] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'May' );
  ShortMonthNames[ 6] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Jun' );
  ShortMonthNames[ 7] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Jul' );
  ShortMonthNames[ 8] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Aug' );
  ShortMonthNames[ 9] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Sep' );
  ShortMonthNames[10] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Oct' );
  ShortMonthNames[11] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Nov' );
  ShortMonthNames[12] := GetLocaleStr( LOCALE_SABBREVMONTHNAME2, 'Dec' );

end; { ReadLocale }

end.

