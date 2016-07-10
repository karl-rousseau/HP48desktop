CONST NUL : Char = #0;                  { Valeur ASCII du caractäre BLANC }

Procedure CursON;                       { Curseur AllumÇ }
Begin
  ASM
    MOV CX,8h
    MOV AH,1h
    INT 10h
  END
End;

Procedure CursOFF;                      { Curseur Eteint }
Begin
  ASM
    MOV CX,100h
    MOV AH,1h
    INT 10h
  END
End;

Function IntToStr(i:LongInt):String;    { Integer -> String }
Var s:string[11];
Begin
  Str(i:8,s); IntToStr:=s; s[0]:=Char(Pred(SizeOf(s)));
End;

Function Repet(C:Char;N:Word):String;   { RÇpÇte N caractäres }
Var Bl : String;
Begin
  FillChar (Bl,N+1,C); Bl[0]:=Chr(N); Repet:=Bl; {Repet[0]:=Chr(N);}
End;

Function NumStr(N, D: Integer): String; { NumÇrique -> String }
Begin
  NumStr[0] := Chr(D);
  while D > 0 do
  begin
    NumStr[D] := Chr(N mod 10 + Ord('0'));
    N := N div 10;
    Dec(D);
  end;
End;

Function Justi(St : String;N : Byte):String; { Met des "blancs" -> n carac. }
Var J : String;                              { = Justification Ö gauche   }
Begin
  J:=St+Repet(NUL,1+N-Length(St));
  Justi:=J; Justi[0]:=Chr(N);
End;

Function UnJusti(St : String):String;   { Enläve les "blancs" Ö droite }
Var J : String;
    P : Byte;
Begin
  J:=St; P:=Length(J);
  While J[P]=NUL do Dec(P);
  UnJusti:=Copy(St,1,P);
End;

Function Replace(St:String;O,N:Char):String; { Remplace un Car. par 1 autre }
Var L : Byte;
Begin
  L:=Length(St);
  While L<>0 do
    begin
      if St[L]=O then St[L]:=N;
      Dec(L);
    end;
  Replace:=St;
End;

Function Majus(St : String):String;     { Met en majuscule un texte }
Var L : Byte;
Begin
  For L:=1 to Length(St) do St[L]:=UpCase(St[L]);
  Majus:=St;
End;

Procedure Clear_Key;                    { Vide buffer Clavier }
Var KbHead : Word ABSOLUTE $40:$1A;
    KbTail : Word ABSOLUTE $40:$1C;
Begin
  ASM CLI END;
  KbHead := $1E;
  KbTail := $1E;
  ASM STI END;
End;

Procedure Wait_Key;                     { Vide buffer + Attend une touche }
Begin
  Clear_Key;
  Repeat Until Keypressed;
End;

Function ReadChar:Char;                 { Lit une touche }
Var Ch: Char;
Begin
  Ch := ReadKey;
  if Ch = #0 then
    case ReadKey of
      #19: Ch := ^R; { Alt-R }
      #31: Ch := ^T; { Alt-S }
      #45: Ch := ^[; { Alt-X }
      #46: Ch := ^C; { Alt-C }
      #50: Ch := ^U; { Alt-M }
      #59: Ch := ^A; { F1    }
      #71: Ch := ^B; { Home  }
      #72: Ch := ^E; { Up    }
      #73: Ch := ^Y; { Pg Up }
      #75: Ch := ^S; { Left  }
      #77: Ch := ^D; { Right }
      #79: Ch := ^F; { Fin   }
      #80: Ch := ^X; { Down  }
      #81: Ch := ^N; { Pg Dn }

      {#82: Ch := ^N;} { Ins   }
      {#83: Ch := ^Y;} { Del   }
    end;
  ReadChar := Ch;
End;

Function LastDir (Path:String):String;  { Donne le dernier rÇp. du path }
Var P : Byte;
Begin
  P:=Length(Path);
  While (P>1) and (Path[P]<>'\') do Dec(P);
  LastDir:=Copy (Path,P+1,Length(Path)-P);
End;

Procedure Error (Err:Byte); { GÇnäre les messages d'erreur }
Var RIP : Boolean;
Begin
  TextAttr := 7+0*16; CursOFF;
  OpenWindow(4,28,NbLn div 2-1,52,NbLn div 2+1,' ERREUR ',
             SingleFrame,15+12*16,7+4*16);
  GotoXY (1,1); ClrEol; RIP:=True;
  Case Err of
    0 : begin Write (' Protection ECRITURE !'); RIP:=False; end;
    1 : Write (' HP48.INI inexistant !');
    2 : Write (' dans HP48.INI ligne 2');
    3 : Write (' dans HP48.INI ligne 3');
    4 : Write (' dans HP48.INI ligne 4');
    5 : Write (' dans HP48.INI ligne 5');
    6 : Write (' dans HP48.INI ligne 6');
    7 : Write (' dans HP48.INI ligne 7');
    8 : Write (' RÇpertoire incorrecte');
    9 : begin Write (' PORT COM non ouvrable'); RIP:=False; end;
   10 : begin Write (' RÇpertoire inexistant'); RIP:=False; end;
   11 : begin Write (' Plus de  PLACE DISQUE'); RIP:=False; end;
   12 : begin Write (' ACCES impossible ?   '); RIP:=False; end;
   13 : begin Write (' TIME OUT !           '); RIP:=False; end;
  End;
  Wait_Key;
  CloseWindow (4); CursON;
  if RIP then Halt (1);
End;