unit _RES;

/////////////////////////////////////////////////////////////////////
//
// Hi-Files Version 2
// Copyright (c) 1997-2004 Dmitry Liman [2:461/79]
//
// http://hi-files.narod.ru
//
/////////////////////////////////////////////////////////////////////

interface

uses
  Objects, Views, Dialogs;

procedure OpenResource;
procedure CloseResource;
function  LoadString( id: Word ) : String;

function ShoeHorn( Dialog: PDialog; Control: PView ) : PView;
procedure SwapDlg(OldDlg, NewDlg : PDialog);

var
  Res: PResourceFile;

const
  // AreaFix
  _SLogSendingHelp        = 128;
  _SLogHelpNotAvail       = 129;
  _SReplyHelpNotAvail     = 130;
  _SLogSendingEchoList    = 131;
  _SReplyListFooter       = 132;
  _SLogSendingEchoQuery   = 133;
  _SReplyQueryFooter      = 134;
  _SLogInvalidAfixCmd     = 135;
  _SReplyInvalidAfixCmd   = 136;
  _SReplyAlreadyDL        = 137;
  _SLogDLinked            = 138;
  _SReplyDLinked          = 139;
  _SLogDUnlinked          = 140;
  _SReplyUnlinked         = 141;
  _SLogUUnlinked          = 142;
  _SPauseWarning          = 143;
  _SReplyWildNotFound     = 144;
  _SLogNoSuchEcho         = 145;
  _SReplyNoSuchEcho       = 146;
  _SSubChangedSubj        = 147;
  _SYourAfixReqSubj       = 148;
  _SLogAfixReply          = 149;
  _SLogWrongAfixPw        = 150;
  _SReplyWrongAfixPw      = 151;
  _SLogStartAfix          = 152;
  _SLogStopAfix           = 153;
  _SLogUplinksLost        = 154;
  _SNotifyUplinksLost     = 155;
  _SNotifyWarnSubj        = 156;
  _SLogDownlinksLost      = 157;
  _SCfmDelAvailRec        = 158;
  _SReplyReqForw          = 159;
  _SLogWriteFwd           = 160;
  _SLogSendingAvail       = 161;
  _SLogInvalidNotifyCmd   = 162;
  _SReplyInvalidNotifyCmd = 163;
  _SNotifyChanged         = 164;
  _SModeTurnedOn          = 165;
  _SModeTurnedOff         = 166;
  _SPauseChanged          = 167;
  _SEchoDenied            = 168;
  _SAfixEchoDenied        = 169;
  _SAfixReplyRW           = 170; // 170..175

  // AreaPane
  _SAloneCmtText          = 200;
  _SMissingText           = 201;
  _SInvalidNumeric        = 202;
  _ScantMoveToSameArea    = 203;
  _SCantMoveAlreadyExists = 204;
  _SLogMovingFileToArea   = 205;
  _SCantMoveSrcNotFound   = 206;
  _SMovingFailed          = 207;
  _SConfirmDelFile        = 208;
  _SCantDelFile           = 209;
  _SCantAloneNearAlone    = 210;
  _SViewerError           = 211;
  _SNoViewer              = 212;
  _SViewersCaption        = 213;
  _SConfirmSaveFilesBbs   = 214;
  _SMoreDLPathCaption     = 215;
  _SCantRenameAreaExists  = 216;
  _SNewAreaName           = 217;
  _SCantDelHostArea       = 218;
  _SConfirmDelArea        = 219;
  _SConfirmDelMultiArea   = 220;
  _SConfirmDelMultiFile   = 221;
  _SFileAreaCounter       = 222; // 222..224
  _SFileCounter           = 225; // 225..227
  _SDirAdded              = 228;

  // EchoPane
  _SNoHostArea            = 250;
  _SNoValidDLPath         = 251;
//  _SUplinksCaption        = 252;
//  _SDownlinksCaption      = 253;
  _SHooksCaption          = 254;
  _SCantRenEchoNameExists = 255;
  _SNewEchoName           = 256;
  _SConfirmDelEcho        = 257;

  // Finder
  _SLogAnswering          = 300;
  _SLogMsgFailed          = 301;
  _SLogPktFailed          = 302;
  _SStartFinder           = 303;

  // Gen
  _SBadAnFile             = 350;
  _SBadAnVer              = 351;
  _SAnFailed              = 352;
  _SLogCheckingAn         = 353;
  _SOpeningAnFile         = 354;
  _SCantOpenAn            = 355;
  _SLogSavingAn           = 356;
  _ScantCreateAn          = 357;
  _SLogNoDizInArc         = 358;
  _SCantSetTmpDir         = 359;
  _SCantDelTmpFile        = 360;
  _SExtRunError           = 361;
  _SExtRunErrLevel        = 362;
  _SDizExtracted          = 363;
  _SRunExternal           = 364;
  _SDizNotBuilt           = 365;
  _SDizBuilt              = 366;
  _SBadFileDate           = 367;
  _SDateShouldFixed       = 368;
  _SForceDiz              = 369;
  _SUpdatedFile           = 370;
  _SNewFile               = 371;
  _SCantSetFTime          = 372;
  _SLogPostInArea         = 373;
  _SBestAreaFailedNoDLC   = 374;
  _SLogScanningFileBase   = 375;
  _SScanFailedNoBbs       = 376;
  _SLogExportFreq         = 377;
  _SLogBuildingBest       = 378;
  _SLogBuildingAll        = 379;
  _SLogLeavingNew         = 380;
  _SLogBuildingNew        = 381;
  _SLogBuildingNewRep     = 382;
  _SLogNothingToAn        = 383;
  _SLogNoNewFiles         = 384;
  _SLogUnrarOpenError     = 385;
  _SLogUnrarError         = 386;
  _SLogUnrarHdrBroken     = 387;
  _SLogAnCreated          = 388;
  _SLeavingNewFiles       = 389;
  _SCfmIgnoreErrors       = 390;

  // Hatch
  _SHatchCaption          = 400;
  _SFileNameCaption       = 401;
  _SFileNotFound          = 402;
  _SLogStartHatcher       = 403;
  _SCantCopyToInbound     = 404;
  _SFileHatchOk           = 405;
  _STicBuilt              = 406;
  _SGetShortPathFailed    = 407;
  _SRenameToShortFailed   = 408;
  _SGetDizFailed          = 409;
  _SHatchDone             = 410;

  // Import
  _SNameExists            = 450;
  _SDLPathExists          = 451;
  _SDLPathNotExists       = 452;
  _SAreaRejected          = 453;
  _SImportingTree         = 454;
  _SImportSummary         = 455;
  _SImportHiFiCaption     = 456;
  _SImportingHiFi         = 457;
  _SLogImportingHiFi      = 458;
  _SLogJustAddLinks       = 459;
  _SLogEchoCreated        = 460;
  _SLogPassthrough        = 461;
  _SLogParking            = 462;
  _SLogNewHostCreated     = 463;
  _SLogAreaNameMissing    = 464;
  _SBadULAddr             = 465;
  _SBadDLAddr             = 466;
  _SBadLineIgnored        = 467;
  _SImportEchoSummary     = 468;
  _SImportAllfixCaption   = 469;
  _SImportingAllfix       = 470;
  _SImpLnkAfixCaption     = 471;
  _SImportingAfixLnk      = 472;
  _SLogAddLink            = 473;
  _SImportLinkSummary     = 474;
  _SImportDMCaption       = 475;
  _SImportingDMT          = 476;
  _SImportBlstCaption     = 477;
  _SImportingBlst         = 478;
  _SBlstBbsSummary        = 479;

  // Main
  _SSaveConfig            = 500;
  _SCmdLineError          = 501;
  _SCreateNewCfg          = 502;
  _SNewCfgDisabled        = 503;
  _SBatchRejected         = 504;
  _SBatchRunning          = 505;
  _SBatchInterrupted      = 506;
  _SNoHelpFile            = 507;

  // MyLib
  _SInvalidBool           = 550;
  _SAskCreateDir          = 551;
  _SMkDirFailed           = 552;
  _SDirNotExists          = 553;
  _SFileMustExists        = 554;
  _SQuotedExpected        = 555;

  // Setup
  _SChooseFACtl           = 600;
  _SBadBakLevel           = 601;
  _SDizCaption            = 602;
  _SArcCaption            = 603;
  _SFetchCaption          = 604;
  _SDefCmtCaption         = 605;
  _SBadStrCaption         = 606;
  _SFinderRobotsCaption   = 607;
  _SForgetCaption         = 608;
  _SAddrExists            = 609;
  _SBadAddr               = 610;
  _SCfmFileApi            = 611;
  _SFapiNotAvail          = 612;
  _SFapiNeedCompact       = 613;
  _SExclCaption           = 614;
  _SNeedReformat          = 615;
  _SEditDenyCaption       = 616;

  // SetupEcho
  _SAfixRobots            = 650;
  _SCantChgAddrDupe       = 651;
  _SEmptyPwd              = 652;
  _SCantAddLinkDupe       = 653;
  _SCantAddLinkEmptyPwd   = 654;
  _SAskKillLink           = 655;
  _SUnknownAvailLink      = 656;
  _SAvailAddrDupe         = 657;
  _SBrowseAvailCaption    = 658;
  _SCfmClrAllRights       = 659;
  _SCfmClrWriteRights     = 660;

  // _BSY
  _SBusyCaption           = 700;
  _SBusyMsg1              = 701;
  _SBusyMsg2              = 702;
  _SKillFlagBtn           = 703;
  _SExitBtn               = 704;
  _SCantKillFlag          = 705;
  _SWaiting               = 706;

  // _CFG
  _SBadCmdLine            = 750;
  _SBadChapter            = 751;
  _SBadToken              = 752;
  _SBadPoster             = 753;
  _SBadArea               = 754;
  _SBadLinks              = 755;
  _SLinkDupe              = 756;
  _SBadLinkToken          = 757;
  _SLogReadingCfg         = 758;
  _SReadingCfg            = 759;
  _SLogSavingCfg          = 760;
  _SBadAvail              = 761;
  _SBadAvailToken         = 762;

  // _Fareas

//_SWrongCmt              = 800; died
  _SFilesBbsMissing       = 801;
  _SNoFilesBbs            = 802;
  _SDroppingMiss          = 803;
  _SLogRescan             = 804;
  _SNoDLPath              = 805;
  _SBadFListFormat        = 806;
  _SBadParanoic           = 807;
  _SDupeAreaDef           = 808;
  _SNoHost                = 809;
  _SNeedHost              = 810;
  _SNoFileAreaCtl         = 811;
  _SReadingFileAreaCtl    = 812;
//  _SBadDir                = 813; died
  _SNoActiveArea          = 814;
  _SSavingFileAreaCtl     = 815;
  _SCantCreateFile        = 816;
  _SReadingFilesBbs       = 817;
  _SSavingFilesBbs        = 818;
  _SDropMissFiles         = 819;
  _SReadingMagic          = 820;
  _SSavingMagic           = 821;
  _SSaveMagicFailed       = 822;
  _SAliasRefNotFound      = 823;
  _SLinkingMagic          = 824;
  _SAskSaveAreaDef        = 825;
  _SLogLoadingAvail       = 826;
  _SBadEchoState          = 827;

  // _Inspector
  _SAloneText             = 850;

  // _Log
  _SMsgWinCaption         = 900;

  // _Report & _Inspector
  _SCantCreateRep         = 950;
  _SCancelled             = 951;
  _SCancelBtn             = 952;
  _SConfirmCancel         = 953;

  // _Script
  _SScriptInitComplete    = 1000;
  _SScriptDoneComplete    = 1001;
  _SBadOperator           = 1002;
  _SEnterFileFrame        = 1003;
  _SLeaveFileFrame        = 1004;
  _SUpdateFileFrameAlone  = 1005;
  _SUpdateFileFrameFile   = 1006;
  _SUpdateFileFrameCompl  = 1007;
  _SEnterRelFileFrame     = 1008;
  _SExitRelFileFrame      = 1009;
  _SEnterCreAreaFrame     = 1010;
  _SExitCreAreaFrame      = 1011;
  _SEnterUpdtAreaFrame    = 1012;
  _SExitUpdtAreaFrame     = 1013;
  _SEnterRelAreaFrame     = 1014;
  _SExitRelAreaFrame      = 1015;
  _SReformatOutsideFLoop  = 1016;
  _SNestedFLoop           = 1017;
  _SOrphanFLoop           = 1018;
  _SNestedALoop           = 1019;
  _SIfNotBool             = 1020;
  _SOrphanElse            = 1021;
  _SOrphanEndif           = 1022;
  _SEmptyDecList          = 1023;
  _SWhileNotBool          = 1024;
  _SOrphanWhile           = 1025;
  _SNoBlockBreak          = 1026;
  _SNewAreaDupe           = 1027;
  _SBadNewArea            = 1028;
  _SLogIncluding          = 1029;
  _SOrphanCopy            = 1030;
  _SCopyAreaNotExists     = 1031;
  _SCopySameArea          = 1032;
  _SCopyNeedVirtual       = 1033;
  _SCopyFileDupe          = 1034;
  _SBadValType            = 1035;
  _SMismatchedBlock       = 1036;
  _SBlockTooNested        = 1037;
  _SLogRunningScript      = 1038;
  _SScriptCancelled       = 1039;
  _SBadRedirArg           = 1040;
  _SLogRedir              = 1041;

  // _Tic
  _SBadSeenBy             = 1050;
  _SBadTicToken           = 1051;
  _STicBuild              = 1052;
  _SCantCreBadTicLog      = 1053;
  _SCantMoveRej           = 1054;
  _STicRejected           = 1055;
  _SOldAttachCut          = 1056;
  _SOldTicDied            = 1057;
  _SMsgHi                 = 1058;
  _SLogNotifying          = 1059;
  _SLogAutoCre            = 1060;
  _SLogHostCre            = 1061;
  _SMsgAutoCre            = 1062;
  _SCantBsoLock           = 1063;
  _SBsoTimeout            = 1064;
  _SCantKillBsy           = 1065;
  _SCantOpenTempLo        = 1066;
  _SCantCreLo             = 1067;
  _SCantAppendLo          = 1068;
  _SCantReadTempLo        = 1069;
  _SUpdatingLo            = 1070;
  _SRestoringLo           = 1071;
  _SErrorSavingLo         = 1072;
  _SKillingDupe           = 1073;
  _SFailed                = 1074;
  _SCantKillFile          = 1075;
  _SDupeKilled            = 1076;
  _SErrCalcCrc            = 1077;
  _SDupeFound             = 1078;
  _SAcceptingTarget       = 1079;
  _SErrorParking          = 1080;
  _SReplacesKill          = 1081;
  _SReplacesFailed        = 1082;
  _SLogSkippingRepl       = 1083;
  _SHookExec              = 1084;
  _SExecError             = 1085;
  _SErrRetCode            = 1086;
  _SLogEatTic             = 1087;
  _SNotOurTic             = 1088;
  _SOurHatchedTic         = 1089;
  _SBadHatchPw            = 1090;
  _SSenderNotOurLink      = 1091;
  _SBadTicPw              = 1092;
  _SNoEchotag             = 1093;
  _SEchoNotExists         = 1094;
  _SLogAutolinked         = 1095;
  _SMsgNewUplink          = 1096;
  _SNotUplink             = 1097;
  _SNoGlueFileName        = 1098;
  _SNoGlueFile            = 1099;
  _SUnableCRC             = 1100;
  _SCRCFailed             = 1101;
  _SNoPasruDir            = 1102;
  _SLogTicPassed          = 1104;
  _SLogFileDied           = 1105;
  _SLogFileNotDied        = 1106;
  _SLogCleanPasru         = 1107;
  _SLogTicTosserStart     = 1108;
  _SLogTicTosserStop      = 1109;
  _SEchoDown              = 1110;
  _SReplyAvailFrom        = 1111;
  _SExpandToLFN           = 1112;
  _STicEchoDenied         = 1113;
  _SReadingBHatch         = 1114;
  _SJobNeed               = 1115;
  _SUnknownOp             = 1116;
  _SBatchComplete         = 1117;
  _SUnclosedJob           = 1118;
  _SDoingJob              = 1119;
  _SJobCancel             = 1120;
  _SBHatchStarted         = 1121;
  _SCouldNotCopyToFileBox = 1122;
  _SCouldNotCreateFileBox = 1123;
  _STryBso                = 1124;
  _SFileBoxRootMissed     = 1125;
  _SGlueHidden            = 1126;
  _SLogTicHeader          = 1127;

  // _pal
  _SOpenPalCaption        = 1200;
  _SSavePalCaption        = 1201;
  _SBadPalFile            = 1202;
  _SConfirmOverwrite      = 1203;

  // _fopen
  _SScanningDrives        = 5000;

{ ========================================================= }

implementation

uses
  SysUtils, Editors, MyLib;

var
  StrList: PStringList;

{ --------------------------------------------------------- }
{ OpenResource                                              }
{ --------------------------------------------------------- }

procedure OpenResource;
var
  S: PBufStream;
begin
  S := New( PBufStream, Init(ChangeFileExt(HomeDir, '.res'), stOpenRead, 8 * 1024 ));
  if S^.Status <> stOk then
  begin
    Writeln( '! Fatal error: can''t open resource file'^M^J );
    Dispose( S, Done );
    Abort;
  end;
  Res := New( PResourceFile, Init( S ) );
  StrList := PStringList(Res^.Get( 'STRLIST' ));
end; { OpenResource }

{ --------------------------------------------------------- }
{ CloseResource                                             }
{ --------------------------------------------------------- }

procedure CloseResource;
begin
  Destroy( StrList );
  Destroy( Res );
end; { CloseResource }

{ --------------------------------------------------------- }
{ LoadString                                                }
{ --------------------------------------------------------- }

function LoadString( id: Word ) : String;
begin
  Result := StrList^.Get( id );
  if Result = '' then
  begin
    Writeln( 'Fatal error: no string resource, id=' + IntToStr(id) );
    Abort;
  end;
end; { LoadString }


{ --------------------------------------------------------- }
{ ShoeHorn                                                  }
{ --------------------------------------------------------- }

const
  ofShoeHorn = $8000;                   { Shoehorn bit          }

function ShoeHorn( Dialog: PDialog; Control: PView ) : PView;
var
  DummyControl  : PView;
  LabelP        : PLabel;
  OldListViewer : PListViewer;
  NewListViewer : PListViewer;
  OldButton     : PButton;
  NewButton     : PButton;
  OldCluster    : PCluster;
  NewCluster    : PCluster;
  OldILine      : PInputLine;
  NewILine      : PInputLine;
  OldSText      : PStaticText;
  NewSText      : PStaticText;
  OldPText      : PParamText;
  NewPText      : PParamText;
  NewMemo       : PMemo;
  I             : Integer;
  R             : TRect;

  {+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
  {                                                                     }
  { TestLabelPtr                                                        }
  {                                                                     }
  { function TestLabelPtr(View : PView) : boolean; far;                 }
  {                                                                     }
  { Description This function returns True if View is a label and its   }
  {             owner is DummyControl.                                  }
  {                                                                     }
  {_____________________________________________________________________}

  function TestLabelPtr(View : PView) : boolean; far;

    begin {TestLabelPtr}

      if (TypeOf(View^) = TypeOf(TLabel)) and
         (PLabel(View)^.Link = PView(DummyControl)) then
            begin
              TestLabelPtr := True;
              Exit;
            end;

      TestLabelPtr := False;

    end;  {TestLabelPtr}

  {+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
  {                                                                     }
  { TestShoeHornBit                                                     }
  {                                                                     }
  { function TestShoeHornBit(View : PView) : boolean; far;              }
  {                                                                     }
  { Description  This function returns True if the shoehorn bit,        }
  {              ofShoeHorn, is set in View's Options.                  }
  {                                                                     }
  {_____________________________________________________________________}

  function TestShoeHornBit(View : PView) : boolean; far;

    begin {TestShoeHornBit}

      TestShoeHornBit := ((View^.Options and ofShoeHorn) <> 0);

    end;  {TestShoeHornBit}

  begin {bShoeHorn}

    { Look in Z-order for first control with shoehorn bit set           }

    DummyControl := PView(Dialog^.FirstThat(@TestShoeHornBit));

    if (DummyControl = NIL) then                { Error !               }
       begin
         ShoeHorn := NIL;
         Exit;
       end
    else
       begin

         { See if a label points to the dummy control so we can change  }
         { its link field.                                              }

         LabelP := PLabel(Dialog^.FirstThat(@TestLabelPtr));
         if (LabelP <> NIL) then
            LabelP^.Link := Control;

         with Control^ do
           begin

             { TView specific fields            }

             Owner      := DummyControl^.Owner;
             Next       := DummyControl^.Next;
             Origin     := DummyControl^.Origin;
             Size       := DummyControl^.Size;
             HelpCtx    := DummyControl^.HelpCtx;
             Options    := DummyControl^.Options and not ofShoeHorn;

           end;

         { Make sure the circular list is intact                        }

         DummyControl^.Prev^.Next := Control;

         { We need to clear the owner field so that we avoid being      }
         { deleted from the dialog box during Done (see TGroup.Done)    }

         DummyControl^.Owner := NIL;

         { Check the type of the original control to see which control  }
         { specific fields we have to transfer to the new control.      }

         if (TypeOf(DummyControl^) = TypeOf(TListViewer)) then
            begin

              OldListViewer := PListViewer(DummyControl);
              NewListViewer := PListViewer(Control);

              with NewListViewer^ do
                begin

                  { TListViewer specific fields      }

                  HScrollBar := OldListViewer^.HScrollBar;
                  if (HScrollBar <> NIL) then
                     HScrollBar^.SetParams(0,0,Range-1,1,1);

                  VScrollBar := OldListViewer^.VScrollBar;
                  if (VScrollBar <> NIL) then
                     VScrollBar^.SetParams(0,0,Range-1,Size.Y-1,1);

                  NumCols    := OldListViewer^.NumCols;
                  TopItem    := 0;

                  if (Dialog^.Current = PView(OldListViewer)) then
                    NewListViewer^.Select;
                  Dispose(OldListViewer,Done);

                end;

            end
         else if (TypeOf(DummyControl^) = TypeOf(TButton)) then
            begin

              OldButton := PButton(DummyControl);
              NewButton := PButton(Control);

              with NewButton^ do
                begin

                  { TButton specific fields         }

                  Title     := AllocStr(OldButton^.Title^);
                  Command   := OldButton^.Command;
                  Flags     := OldButton^.Flags;
                  AmDefault := OldButton^.AmDefault;

                  if (Dialog^.Current = PView(OldButton)) then
                    NewButton^.Select;
                  Dispose(OldButton,Done);

                end;

            end
         else if ((TypeOf(DummyControl^) = TypeOf(TRadioButtons)) or
                (TypeOf(DummyControl^) = TypeOf(TCheckBoxes))) then
            begin

              OldCluster := PCluster(DummyControl);
              NewCluster := PCluster(Control);

              with NewCluster^ do
                begin

                  { TCluster specific fields         }

                  Value   := OldCluster^.Value;
                  Sel     := OldCluster^.Sel;

                  { If Strings is empty, then add the strings from the  }
                  { base control; otherwise, allow the user to also     }
                  { specify the strings at run time.                    }

                  if (Strings.Count = 0) then
                     begin
                       Strings.FreeAll;
                       Strings.SetLimit(OldCluster^.Strings.Count);
                       for I := 0 to (OldCluster^.Strings.Count - 1) do
                       Strings.AtInsert(I,
                           AllocStr(PString(OldCluster^.Strings.At(I))^) );
                     end;

                  if (Dialog^.Current = PView(OldCluster)) then
                    NewCluster^.Select;
                  Dispose(OldCluster,Done);

                end;

            end
         else if (TypeOf(DummyControl^) = TypeOf(TInputLine)) then
            begin

              OldILine := PInputLine(DummyControl);
              NewILine := PInputLine(Control);

              with NewILine^ do
                begin

                  { TInputLine specific fields         }

                  if (Data <> nil) then
                     FreeMem( Data, MaxLen + 1 );
                  GetMem(Data, OldILine^.MaxLen + 1);
                  Data^      := OldILine^.Data^;
                  MaxLen    := OldILine^.MaxLen;
                  CurPos    := OldILine^.CurPos;
                  FirstPos  := OldILine^.FirstPos;
                  SelStart  := OldILine^.SelStart;
                  SelEnd    := OldILine^.SelEnd;

                end;

              if (Dialog^.Current = PView(OldILine)) then
                NewILine^.Select;
              Dispose(OldILine,Done);

            end
         else if (TypeOf(DummyControl^) = TypeOf(TStaticText)) then
            begin

              OldSText := PStaticText(DummyControl);
              NewSText := PStaticText(Control);

              with NewSText^ do
                begin

                  { TStaticText specific fields         }

                  Text := AllocStr(OldSText^.Text^);

                end;

              if (Dialog^.Current = PView(OldSText)) then
                NewSText^.Select;
              Dispose(OldSText,Done);

            end
         else if (TypeOf(DummyControl^) = TypeOf(TParamText)) then
            begin

              OldPText := PParamText(DummyControl);
              NewPText := PParamText(Control);

              with NewPText^ do
                begin

                  { TParamText specific fields          }

                  Text       := AllocStr(OldPText^.Text^);
                  ParamCount := OldPText^.ParamCount;

                end;

              if (Dialog^.Current = PView(OldPText)) then
                NewPText^.Select;
              Dispose(OldPText,Done);

            end
         else if TypeOf( DummyControl^ ) = TypeOf( TView ) then
            begin
              Dispose( PView(DummyControl), Done );
            end;

         ShoeHorn := Control;

       end;

  end;  {ShoeHorn}

{***********************************************************************}
{                                                                       }
{ SwapDlg                                                               }
{             Replace a standard dialog with a user dialog box          }
{                                                                       }
{ procedure   SwapDlg( OldDlg, NewDlg : PDialog );                      }
{                                                                       }
{             OldDlg          Pointer to the dialog box which is        }
{                               being replaced.                         }
{             NewDlg          Pointer to the user dialog box.           }
{                                                                       }
{ Description This procedure copies all data from the OldDlg original   }
{             dialog box into the NewDlg object which is created by     }
{             the user.  This provides the programmer with a simple     }
{             way to use ResEdit to create a dialog box "shell" which   }
{             can contain any number of standard or "custom" controls,  }
{             and then swap a user dialog box object derived from       }
{             TDialog to contain the controls.  The user dialog box     }
{             object can then implement its own event handling or       }
{             override any TDialog method.                              }
{                                                                       }
{             We start by copying all of the data from the old dialog   }
{             to the new dialog.  Then we change the pointers of the    }
{             old dialog to nil in preparation for disposal since the   }
{             new dialog will be maintaining the previous data.  Next,  }
{             all of the Owner fields of the dialog box subviews are    }
{             updated to reflect the change in ownership.  Finally, the }
{             old dialog box is disposed and a pointer to the new one   }
{             is returned.                                              }
{_______________________________________________________________________}

procedure SwapDlg(OldDlg, NewDlg : PDialog);

  {+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
  {                                                                     }
  { ChangeOwner                                                         }
  {             Change the owner field to that of the new dialog        }
  {                                                                     }
  { procedure   ChangeOwner( PSubView : PView ); far;                   }
  {                                                                     }
  {             PSubView        Pointer to the control whose owner      }
  {                               field will be changed.                }
  {                                                                     }
  { Description This iterator procedure is used in a dialog box to      }
  {             change the Owner field of each subview to the address   }
  {             of the new dialog box NewDlg.                           }
  {_____________________________________________________________________}

  procedure ChangeOwner(PSubView : PView); far;

    begin {ChangeOwner}

      PSubView^.Owner := NewDlg;

    end;  {ChangeOwner}

  var
    POld, PNew : Pointer;

  begin {SwapDlg}

    if (NewDlg^.Frame <> nil) then
       Dispose(NewDlg^.Frame, Done);

    POld := Ptr(Ofs(OldDlg^)+SizeOf(Word));
    PNew := Ptr(Ofs(NewDlg^)+SizeOf(Word));

    Move(POld^,PNew^,SizeOf(OldDlg^)-2);

    with OldDlg^ do
      begin

        Owner   := nil;
        Next    := nil;
        Last    := nil;
        Current := nil;
        Buffer  := nil;
        Frame   := nil;
        Title   := nil;

      end;

    NewDlg^.ForEach(@ChangeOwner);

    Dispose(OldDlg,Done);

  end;  {SwapDlg}

end.

