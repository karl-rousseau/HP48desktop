(**********************************)
(** HP48 DESKTOP v.4    30/10/93 **)
(**********************************)
(* Environnement complet pour     *)
(* manipuler les objets de la 48  *)
(* incluant :                     *)
(*  . X,YModem (rapide)           *)
(*  . Gestion des r‚pertoires     *)
(*  . BibliothŠque HPbible        *)
(*  . Editeur de GROBs b/w & gris *)
(*  . D‚sassemblage prog HP48     *)
(**********************************)
(* (c) ROUSSEAU Karl alias HPZERO *)
(**********************************)
(*  Programme en Turbo Pascal 5&+ *)
(*  Bientot sous T-P Windows 1.5  *)
(**********************************)
(*  Greeting to AKIRA             *)
(*              HAMELIN F-R       *)
(*              GUERIN Franck     *)
(*           et tous les HPistes  *)
(**********************************)

{$S-,R-}
{$M 16384,0,655360}
Uses Crt,Dos,Win,CommPkg,CRC,XYmodem,XYpacket;

Const NbLn  : Byte = 25;  { Nb de lignes … l'‚cran 25/43/50 }
      RSCom : String = 'COM1~';
      Speed : String = '9600~';
      Proto : String = 'X~mod';
Type DirPtr   = ^DirRec;
     DirRec   = Record
                  Attr: Byte;
                  Time: Longint;
                  Size: Longint;
                  Name: String[12];
                End;
{Var Memory     : LongInt;}
Var WindowCount: Integer;
    WinNo      : Byte;
    Done       : Boolean;
    Ch         : Char;
    Count      : Integer;
    Desktop    : PathStr;
    Path,Ori   : PathStr;
    Spec       : String[4];
    Dir        : Array[0..512 - 1] of DirPtr;
    ListSelec  : Array[0..30] of Record { liste des fichiers s‚lectionn‚s }
                                   Che : PathStr;
                                   Nom : String;
                                 End;
    NbSelec    : Byte;                  { Nb de fichiers s‚lectionn‚s }
    Posi       : 1..512;
    Curs       : 1..21;
    Cfg        : Text;    { Fichier de configuration }

    Port       : Integer; { RS232 }
    Filename   : String;
    BaudRate   : LongInt;
    Protocol   : Char;
    Buffer     : BufferType;
    OneKflag   : Boolean; { Paquet de 128/1K }
    NCGbyte    : Byte;
    BatchFlag  : Boolean; { Mode Batch en Ymodem }
    Flag       : Boolean;

{$I SAISIE.INC}
{$I OUTILS.INC}
{$I SCANHP.INC}

Procedure LOGO;
Begin
  SelectWindow (3,False); TextAttr := 14+2*16; ClrScr; TextColor (11);
  GotoXY (5,02); Write ('(C) R‚alis‚ par  Û Û ÛÛÛ ±±± ±±± ±±± ±±±');
  GotoXY (5,03); Write ('v.4 le 30/10/93  Û Û Û Û   ± ±   ± ± ± ±');
  GotoXY (5,04); Write ('    en           ÛÛÛ ÛÛÛ  ±  ±±  ±±± ± ±');
  GotoXY (5,05); Write ('alias ROUSSEAU   Û Û Û   ±   ±   ±±  ± ±');
  GotoXY (5,06); Write ('      KARL       Û Û Û   ±±± ±±± ± ± ±±±');
  GotoXY (12,04); TextColor ( 1); Write ('FR');
                  TextColor (15); Write ('AN');
                  TextColor ( 4); Write ('CE');
End;

Procedure Initial; { Û Partie qui initialise les variables & fenˆtres Û }
Var Lgn : String;
Begin
  WindowCount:=0; WinNo:=2; NbSelec:=0; Count:=0;
  CheckBreak := True; DirectVideo:=True;
  CursON;

  GetDir (0,Desktop); { Path du r‚pertoire ou est HP48.EXE }
  Path:='';           { Path du r‚pertoire en cours }
  Spec:='\*.*';
  if Length(Desktop)<=3 then Desktop:=Copy(Desktop,1,2); { Si ?:\ }

  Assign (Cfg,Desktop+'\HP48.INI'); {$i-} ReSet (Cfg); {$i+}
  if IOresult<>0 then Error(1);
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET PATH ' then Error(2)
  else Path:=Copy(Lgn,10,Length(Lgn)-9);
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET PORT ' then Error(3)
  else RSCom:='COM'+Copy(Lgn,13,1)+'~';
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET BAUD ' then Error(4)
  else Speed:=Copy(Lgn,10,4)+'~';
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET MODE ' then Error(5)
  else Proto:=Copy(Lgn,10,1)+'~mod';
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET SIZE ' then Error(6)
  else if Copy(Lgn,10,3)='128' then OneKflag:=False else OneKflag:=True;
  ReadLn (Cfg,Lgn);
  If Copy(Lgn,1,9)<>'SET LINE ' then Error(7)
  else
    begin
      NbLn:=10*(Ord(Lgn[10])-48)+Ord(Lgn[11])-48;
      if NbLn<>25 then TextMode (Lo(LastMode)+Font8x8) { Mode d'‚cran }
      else TextMode (Lo(LastMode)+CO80);
    end;
  Close (Cfg);

  { V‚rif. du chemin }
  {$i-} ChDir (Path); {$i+}
  if IOresult<>0 then Error (8);
  Ori:=Path;     { Path du r‚pertoire pour la HP48 }

  TextAttr := White + Blue * 16;     { Cr‚ation de l'environnement }
  Window(1,1,80,NbLn); FillWin(#178, Cyan + Blue * 16);

  TextColor (31);
  GotoXY (63,2); WriteLn ('Û Û ÛÛÛ  Û   ÛÛÛ');
  GotoXY (63,3); WriteLn ('Û Û Û Û Û    Û Û');
  GotoXY (63,4); WriteLn ('ÛÛÛ ÛÛÛ Û Û  ÛÛÛ');
  GotoXY (63,5); WriteLn ('Û Û Û   ÛÛÛÛ Û Û');
  GotoXY (63,6); WriteLn ('Û Û Û     Û  ÛÛÛ');
  TextAttr:=14+4*16; GotoXY (63,8); WriteLn (#17' F1 = AIDE '#16);

  { Û Fenˆtre nø1 : chemin,... Û }
  TextAttr := 7+1*16;
  OpenWindow(1,27,2,60,8,#17' Renseignements '#16,SolideFrame,15+1*16,7+1*16);
  ClrScr;

  { Û Fenˆtre nø2 : Catalogue Û }
  TextAttr := 7+4*16;
  OpenWindow(2,1,1,25,NbLn,#17' Catalogue HP/48 '#16,DoubleFrame,14+2*16,7+4*16);
  ClrScr;

  { Û Fenˆtre nø3 : DESKTOP Û }
  TextAttr := 14+2*16;
  OpenWindow(3,27,10,79,NbLn-1,#17' HP48 DESKTOP '#16,EmptyFrame,15+1*16,7+1*16);
  LOGO; WindowCount:=3;
End;

Procedure AIDE;
Var Deb : Integer;
Begin
  { Û Fenˆtre d'Aide Û }
  TextAttr := 7+1*16;
  OpenWindow(9,27,10,79,NbLn-1,' AIDE globale pour HP DeskTop ',
                                 PokerFrame,15+12*16,7+1*16);
  CursOFF; ClrScr;
  Button   ('  F1   ',1,02,14+4*16,3+16);
  WriteStr (10,02,'Cette Aide puis les autres pages.',14+2*16);

  Button   (' '#24' , '#25' ',1,04,14+4*16,3+16);
  WriteStr (10,04,'Se d‚placer dans la liste des fichiers.',14+2*16);

  Button   ('  Pg'#25'  ',1,06,14+4*16,3+16);
  WriteStr (10,06,'Mise en mode R‚ception du micro.',14+2*16);

  Button   ('  Pg'#24'  ',1,08,14+4*16,3+16);
  WriteStr (10,08,'Lance le transfert des fichiers marqu‚s',14+2*16);
  WriteStr (10,09,'par "'#17'Ù" en utilisant les paramŠtres de',14+2*16);
  WriteStr (10,10,'ALT C (Besoin de X ou Ymodem sur HP48).',14+2*16);

  Button   ('  '#17'Ù   ',1,12,14+4*16,3+16);
  WriteStr (10,12,'D‚/S‚lectionne des fichiers ou change ',14+2*16);
  WriteStr (10,13,'de catalogue sans perdre la s‚lection.',14+2*16);

  If NbLn=25 then
    begin Deb:=-13; Repeat Until ReadChar=^A; ClrScr; end else Deb:=0;

  Button   ('HomeFin',1,15+Deb,14+4*16,3+16);
  WriteStr (10,15+Deb,'Revenir au d‚but ou en fin de liste.',14+2*16);

  Button   ('  '#17'ÄÄ  ',1,17+Deb,14+4*16,3+16);
  WriteStr (10,17+Deb,'D‚s‚lection totale des fichiers.',14+2*16);

  Button   (' Alt C ',1,19+Deb,14+4*16,3+16);
  WriteStr (10,19+Deb,'Configure l''environnement HP DeskTop.  ',14+2*16);
  WriteStr (10,20+Deb,'Les paramŠtres de communication doivent',14+2*16);
  WriteStr (10,21+Deb,'correspondre … ceux de la HP48 ds IOPAR',14+2*16);

  Button   ('(Alt G)',1,23+Deb,14+4*16,3+16);
  WriteStr (10,23+Deb,'Editeur d''images au format GROB de la HP48',14+2*16);

  Button   ('(Alt V)',1,25+Deb,14+4*16,3+16);
  WriteStr (10,25+Deb,'Editeur de fichiers au format binaire HP.',14+2*16);

  If NbLn=25 then
    begin Deb:=-25; Repeat Until ReadChar=^A; ClrScr; end else Deb:=0;

  Button   (' Alt M ',1,27+Deb,14+4*16,3+16);
  WriteStr (10,27+Deb,'Met … jour la base de donn‚es HP BIBLE.',14+2*16);

  Button   (' Alt R ',1,29+Deb,14+4*16,3+16);
  WriteStr (10,29+Deb,'Permet de modifier/rechercher ds la BIBLE',14+2*16);

  Button   (' Alt S ',1,31+Deb,14+4*16,3+16);
  WriteStr (10,31+Deb,'Affiche les statistiques de la BIBLE.',14+2*16);

  Button   (' Alt X ',1,33+Deb,14+4*16,3+16);
  WriteStr (10,33+Deb,'ou ESC pour sortir de HP DeskTop.  ',14+2*16);

  WriteStr (10,35+Deb,'Ce programme est un SHAREWARE donc ',14+2*16);
  WriteStr (10,36+Deb,'vous pouvez librement le diffuser …',14+2*16);
  WriteStr (10,37+Deb,'vos ami(e)s.                       ',14+2*16);

  Repeat Until ReadChar=^A;
  CloseWindow (9); CursON;
End;

Procedure CONFIG; { Û Configuration Û }
Var N_NbLn  : Byte;
    N_RSCom : String;
    N_Speed : String;
    N_Proto : String;
    N_One   : Boolean;
Begin
  TextAttr := 7+1*16; CursOFF;
  OpenWindow(4,30,NbLn div 2-7,50,NbLn div 2+7,' Configuration ',
             SingleFrame,15+12*16,7+1*16);
  ClrScr;
  N_NbLn:=NbLn; N_RSCom:=RSCom; N_Speed:=Speed; N_Proto:=Proto; N_One:=OneKflag;
  Repeat
    WriteStr (2,02,' PORT   '+#16,14+2*16);
    Button   (' '+N_RSCom+' ',12,02,14+4*16,3+16);
    WriteStr (2,04,' SPEED  '+#16,14+2*16);
    Button   (' '+N_Speed+' ',12,04,14+4*16,3+16);
    WriteStr (2,06,' PROTOC '+#16,14+2*16);
    Button   (' '+N_Proto+' ',12,06,14+4*16,3+16);
    WriteStr (2,08,' SIZE   '+#16,14+2*16);
    if N_One then
      Button   (' 1024o',12,08,14+4*16,3+16)
    else
      Button   ('  128o',12,08,14+4*16,3+16);
    WriteStr (17,08,'o',15+4*16);
    WriteStr (2,10,' ECRAN  '+#16,14+2*16);
    Button   (' '+Chr(48+Round(N_NbLn div 10))+
              Chr(48+N_NbLn-10*Round(N_NbLn div 10))+
              ' l ',12,10,14+4*16,3+16);
    WriteStr (16,10,'l',15+4*16);
    Button   (#17'Ù SAUVE',2,12,14+4*16,3+16);
    Button   ('<ESC>',13,12,14+4*16,3+16);

    Ch:=ReadKey;
    Case UpCase(Ch) of
      'L' :      if N_NbLn=25 then N_NbLn:=43
            else if N_NbLn=43 then N_NbLn:=50
            else if N_NbLn=50 then N_NbLn:=25;
      '1' : if N_RSCom='COM1~' then N_RSCom:='COM2~' else N_RSCom:='COM1~';
      '0' :      if N_Speed='1200~' then N_Speed:='9600~'
            else if N_Speed='2400~' then N_Speed:='1200~'
            else if N_Speed='4800~' then N_Speed:='2400~'
            else if N_Speed='9600~' then N_Speed:='4800~';
      'X' : if N_Proto='X~mod' then N_Proto:='Y~mod';
      'Y' : if N_Proto='Y~mod' then N_Proto:='X~mod';
      'O' : if N_One then N_One:=False else N_One:=True;
      #13 : begin { SAUVE paramŠtres }
              RSCom:=N_RSCom; Speed:=N_Speed; Proto:=N_Proto; OneKflag:=N_One;
              Assign  (Cfg,Desktop+'\HP48.INI'); {$i-} ReWrite (Cfg); {$i+}
              if IOresult<>0 then
              begin Error(11); CloseWindow(4); SelectWindow(2,True); Exit; end;
              WriteLn (Cfg,'SET PATH '+Ori);
              WriteLn (Cfg,'SET PORT '+Copy(RSCom,1,4));
              WriteLn (Cfg,'SET BAUD '+Copy(Speed,1,4));
              WriteLn (Cfg,'SET MODE '+Copy(Proto,1,1)+'modem');
              if N_One then WriteLn (Cfg,'SET SIZE 1024')
              else WriteLn (Cfg,'SET SIZE 128');

              if N_NbLn=25 then WriteLn (Cfg,'SET LINE 25');
              if N_NbLn=43 then WriteLn (Cfg,'SET LINE 43');
              if N_NbLn=50 then WriteLn (Cfg,'SET LINE 50');
              Close (Cfg);
            end;
    End;
  Until UpCase(Ch) in [#13,#27];

  CloseWindow (4); CursON;
  SelectWindow (1,False); { MAJ de la fenˆtre renseignements }
  GotoXY (1,5);
  Write(' Transfert : ',
        Copy(RSCom,1,4),' ',
        Copy(Speed,1,4),' ',
        Proto[1],'modem');
  SelectWindow (2,True);
End;

Procedure FindFiles; { Û Recherche les fichiers du r‚pertoire Û }
Var F     : SearchRec;
    Total : LongInt;
    j     : Word;
    nb    : Word;
Begin
  SelectWindow (1,False); TextAttr:=7+1*16; ClrScr;
  If Count<>0 then { Û Remise … jour de la pile Û }
    For j:=Count-1 downto 0 do FreeMem (Dir[j],SizeOf(DirRec));
  Count := 0; Total:=0;
  if Length (Path)=3 then Path:=Copy(Path,1,2); { Si Path=C:\ alors Path=C: }
  FindFirst (Path+Spec, ReadOnly + Directory + Archive, F);
  while (DosError = 0) and (Count < 512) do
  begin
    GetMem (Dir[Count],SizeOf(DirRec));
    Move (F.Attr, Dir[Count]^,Length(F.Name) + 10);
    Inc (Total,Dir[Count]^.Size); Inc (Count);
    FindNext (F);
  end;
  Assign (Bib,DeskTop+'\HP_Bible');
  {$i-} ReSet (Bib,SizeOf(Lg)); nb:=FileSize(Bib); Close(Bib); {$i+}
  if IOResult=0 then WriteLn (nb:5,' fichiers dans la Bible')
  else WriteLn (' Pas de BIBLE HP');
  Write(' Chemin ',Path); ClrEol; WriteLn;
  Write(' ',Count,' fichiers : ',Total div 1024,' Ko'); ClrEol; WriteLn;
  Write(' Octets libres : ',DiskFree(Ord(Path[1])-64) div 1024,' Ko'); WriteLn;
  Write(' Transfert : ',Copy(RSCom,1,4),' ',Copy(Speed,1,4),' ',Proto[1],'modem');
  {Write(' M‚moire restante ',MemAvail,' octets');}
End;

Function Donne(Nu:Word):String; { 1óNuóCount : Nø du fichier }
Var I,P : Integer;
    N   : NameStr;
    E   : ExtStr;
    L   : String[20];
Begin
  if Count = 0 then
      begin Donne:='Aucun fichier'; Exit; end;
  if Nu>Count then begin Donne:=''; Exit; end;
  with Dir[Nu-1]^ do
  begin
    P := Pos('.', Name);
    if P > 1 then
    begin
      N := Copy(Name, 1, P - 1);
      E := Copy(Name, P + 1, 3);
    end else
    begin
      N := Name; E := '';
    end;
    L:=N+Repet(' ',8-Length(N))+'.'+E+Repet(' ',3-Length(E));
    if Attr and Directory <> 0 then
      L:=L+'<DIR>' else L:=L+IntToStr(Size);
  end; Donne:=L; Donne[0]:=Char(Length(L));
End;

Procedure Montre(No:Word;Barre:Boolean);
Var i   : Byte;
    Nom : String;
Begin
  if Barre then     { Montre le s‚lecteur }
    begin
      TextAttr:=15+4*16;
      GotoXY (1,Curs); Write (' ',Donne(No)); ClrEol; GotoXY (1,Curs);
    end
  else
    begin           { Montre les fichiers }
      TextAttr:=7+4*16;
      For i:=0 to 30 do { Analyse les fichiers s‚lectionn‚s }
        begin
          Nom:=Donne(No);
          If Pos(' ',Nom)>8 then Nom:=Copy(Nom,1,12)
          else Nom:=Copy(Nom,1,Pos(' ',Nom)-1)+'.'+Copy(Nom,10,3);

          if ListSelec[i].Nom=Nom then TextAttr:=4+7*16;
        end;
      Write (' ',Donne(No)); ClrEol;
    end;
End;

Procedure Affiche; { Û Affiche les fichiers du r‚pertoires Û }
Var i,nb : Word;
    Nom  : String;
    P    : Word;
Label ReAff;
Begin
ReAff:
  SelectWindow (2,True); ClrScr;
  For i:=1 to NbLn-3 do   { Affichage }
    begin Montre(i,False); WriteLn; end;
  Montre(NbLn-2,False);
  Done:=False; Posi:=1; Curs:=1;
  Montre(Posi,True);

  Repeat
    Ch:=ReadChar;
    Case Ch of
      'A'..'z' : Begin                       { Û Va … la 1ere lettre Û }
                   For P:=Posi+1 to Count do
                     If Copy(Donne(P),1,1)=UpCase(Ch) then
                       begin Posi:=P; Curs:=1; P:=Count; end;
                   For P:=1 to NbLn-3 do { R‚affiche }
                     begin Montre(Posi+P-1,False); WriteLn; end;
                   Montre(Posi+P-1+NbLn-2,False);
                 End;
      ^U : Begin                             { Û Scanne les prog. HP Û }
             SelectWindow (3,False); SCAN; LOGO;
             FindFiles; SelectWindow (2,True);
           End;
      ^R : Begin                             { Û Modifie la Bible Û }
             SelectWindow (3,False); SGBD; LOGO;
             SelectWindow (1,False); { MAJ de la fenˆtre renseignements }
             GotoXY (1,1);
             Assign (Bib,DeskTop+'\HP_Bible');
             {$i-} ReSet (Bib,SizeOf(Lg)); nb:=FileSize(Bib); Close(Bib); {$i+}
             if IOResult=0 then WriteLn (nb:5,' fichiers dans la Bible')
             else WriteLn (' Pas de BIBLE HP');
             SelectWindow (2,True);
             Wait_Key;
           End;
      ^T : Begin                             { Û Affiche les STATs Û }
             SelectWindow (3,False); STATISTIQUE;
             LOGO; SelectWindow (2,True);
             Wait_Key;
           End;
      ^A : Aide;                             { Û Aide Û }
      #13: Begin
             Nom:=Donne(Posi);
             P:=Pos('<DIR>',Nom);
             If P<>0 then                         { Û Chg de r‚pertoire Û }
               begin
                 Sound (500); Delay(10); NoSound;
                 if Path<>'\' then
                 Path:=Path+'\'+Dir[Posi-1]^.name;
                 {$i-} ChDir (Path); GetDir (0,Path); {$i+}
                 if IOresult<>0 then begin Error(10); Exit; end;
                 FindFiles;
                 Affiche;
               end;
             If (P=0) and (NbSelec<31) then       { Û S‚lection d'1 fichier Û }
               begin
                 ListSelec[NbSelec].Che:=Path;
                 If Pos(' ',Nom)>8 then Nom:=Copy(Nom,1,12)
                 else Nom:=Copy(Nom,1,Pos(' ',Nom)-1)+'.'+Copy(Nom,10,3);
                 ListSelec[NbSelec].Nom:=Nom;
                 Inc(NbSelec); Sound (100); Delay (15); NoSound;
                 Montre (Posi,False);                 { DOWN }
                 GotoXY(1,WhereY+1); Inc(Posi); Inc(Curs);
                 if Posi>Count then begin Posi:=Count; Dec(Curs); end;
                 if Curs=NbLn-1 then
                 begin Curs:=NbLn-2; GotoXY (1,1); DelLine; GotoXY (1,NbLn-2); End;
               end;
           End;
      #8 : Begin                                  { Û D‚selection totale Û }
             For i:=0 to 30 do
               begin ListSelec[i].Che:=''; ListSelec[i].Nom:=''; end;
             NbSelec:=0; ClrScr; Affiche;
           End;
      ^N : Begin                                  { Û R‚ception Û }
             SelectWindow (3,False); ClrScr;
             if Proto='X~mod' then
               begin
                 Protocol := 'X';
                 NCGbyte  := $15;
                 BatchFlag:= FALSE;
                 WriteLn ('Protocol = XMODEM');
               end
             else
               begin
                 Protocol := 'Y';
                 NCGbyte  := Ord('C');
                 BatchFlag:= TRUE;
                 WriteLn ('Protocol = YMODEM');
               end;
             if RSCom='COM1~' then Port     := 1;
             if RSCom='COM2~' then Port     := 2;
             if Speed='9600~' then BaudRate := 9600;
             if Speed='4800~' then BaudRate := 4800;
             if Speed='2400~' then BaudRate := 2400;
             if Speed='1200~' then BaudRate := 1200;

             Open_Com (Port,BaudRate,'N',2048,2048); { Init. RS232 }
             If not Port_Open (Port) then begin Error(9); Exit; end;
             InitCRC;
             if BatchFlag then
               repeat
                 WriteLn ('PRET pour un fichier');
                 Filename := '';
                 Flag := RxyModem(Port,Filename,Buffer,NCGbyte,BatchFlag);
               until KeyPressed or (Length(Filename) = 0)
             else
               begin (* Non Batch *)
                 WriteLn ('Entrer le nom du fichier : ');
                 Filename:='';
                 ReadLn (Filename);
                 if Length(Filename) <> 0 then
                   Flag := RxyModem(Port,Filename,Buffer,NCGbyte,BatchFlag);
               end;
             Sound (1500); Delay (5); NoSound; LOGO; Affiche;
           End;
      ^Y : Begin                                  { Û Transfert Û }
             If NbSelec<>0 then
             begin
               SelectWindow (3,False); ClrScr;
               if Proto='X~mod' then
                 begin
                   Protocol := 'X';
                   NCGbyte  := $15;
                   BatchFlag:= FALSE;
                   WriteLn ('Protocol = XMODEM');
                 end
               else
                  begin
                   Protocol := 'Y';
                   NCGbyte  := Ord('C');
                   BatchFlag:= TRUE;
                   WriteLn ('Protocol = YMODEM');
                 end;
               if RSCom='COM1~' then Port     := 1;
               if RSCom='COM2~' then Port     := 2;
               if Speed='9600~' then BaudRate := 9600;
               if Speed='4800~' then BaudRate := 4800;
               if Speed='2400~' then BaudRate := 2400;
               if Speed='1200~' then BaudRate := 1200;

               Open_Com (Port,BaudRate,'N',2048,2048); { Init. RS232 }
               If not Port_Open (Port) then begin Error(9); Exit; end;
               InitCRC;

               For i:=0 to NbSelec-1 do                { Envois des fichiers }
                 begin
                   TextAttr:=14+6*16;
                   WriteLn; WriteLn (' Fichier ',ListSelec[i].Nom);
                   TextAttr:=14+2*16; ClrEol;
                   {$i-} ChDir (ListSelec[i].Che); {$i+}
                   if IOresult<>0 then Error(10);
                   Filename:=ListSelec[i].Nom;
                   Flag := TxyModem(Port,Filename,Buffer,OneKflag,BatchFlag);
                   if Flag and not BatchFlag then { Attente si Non Batch }
                     begin
                       WriteLn; WriteLn (' Une touche pour continuer ...');
                       Wait_Key;
                     end;
                 end;
               if Flag and BatchFlag then { Fin du Batch }
                 begin
                   (* BATCH -> Send fichier vide *)
                   Filename := '';
                   Flag := TxyModem(Port,Filename,Buffer,OneKflag,BatchFlag);
                 end;

               Close_Com (Port);

               Sound (1500); Delay (5); NoSound; LOGO; Affiche;
             end;
           End;
      ^C : Begin CONFIG; End;                     { Û Fenˆtre de Config Û }
      ^S : GotoXY(WhereX - 1, WhereY);
      ^D : GotoXY(WhereX + 1, WhereY);
      ^B : Goto ReAff;                            { Û Home Û }
      ^F : Begin                                  { Û Fin  Û }
             Montre (Posi,False);
             if Count<(NbLn-2) then Curs:=Count else Curs:=NbLn-2;
             Posi:=Count;
             SelectWindow (2,True); ClrScr;
             For i:=1 to Curs-1 do   { Affichage }
             begin Montre(Posi-Curs+i,False); WriteLn; end;
             Montre (Posi,True);
           End;
      ^E : Begin                                  { Û Up Û }
             Montre (Posi,False);
             GotoXY(1,WhereY-1); Dec(Posi); Dec(Curs);
             if Posi<1 then begin Posi:=1; Curs:=1; end;
             if Curs<0 then begin Curs:=1; end;
             if Curs=0 then begin GotoXY (1,1); InsLine; Curs:=1; end;
           End;
      ^X : Begin                                  { Û Down Û }
             Montre (Posi,False);
             GotoXY(1,WhereY+1); Inc(Posi); Inc(Curs);
             if Posi>Count then begin Posi:=Count; Dec(Curs); end;
             if Curs=NbLn-1 then
               begin Curs:=NbLn-2; GotoXY (1,1); DelLine; GotoXY (1,NbLn-2); End;
           End;
      ^[ : Done:=true;                            { Û EXIT Û }
    End;

    if (Posi<>Count) or (Posi<>1) then Montre (Posi,True); { Û Affichage Û }
  Until Done;
End;

Begin
  {MEMORY:=memavail;}
  Initial;
  { Û Affichage du Catalogue Û }
  FindFiles;
  Affiche;
  If Count<>0 then { Û Remise … jour de la pile Û }
    For WinNo:=Count-1 downto 0 do FreeMem (Dir[WinNo],SizeOf(DirRec));
  {$i-} ChDir (Desktop); {$i+}
  if IOresult<>0 then Error(8);
  CloseWindow (3); CloseWindow (2); CloseWindow (1);
  CursON; Window(1,1,80,NbLn); TextAttr:=7; ClrScr;
  {Write (MemAvail-Memory);}
End.
