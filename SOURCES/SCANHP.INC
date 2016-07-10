{----------------------------}
{-- Scanner de programmes  --}
{-- et MAJ d'une BIBLE HP  --}
{----------------------------}
{-- (C) ROUSSEAU Karl 1993 --}
{----------------------------}

Type NivType = Array [0..15] of Integer;
     Str55   = String [55];
     Sdir    = RECORD                  { Element liste des s/dir }
                 Nom  : String [13];
                 Suiv : Pointer;
               END;
     Lin     = RECORD                  { Structure du fichier temporaire }
                 Path : String [55];
                 Nom  : String [12];
                 Size : LongInt;
                 Date : LongInt;
                 Lib  : Boolean;
                 Etat : String [3];
               END;
     Ligne   = RECORD                  { Structure de la Bible HP }
                 Nom  : String [12];
                 Cata : String [8];
                 Aute : String [8];
                 Note : String [2];    {AB,B,TB,E!}
                 Id   : String [3];    {NEW,LIB,RPL,EXT,ASM,GRB}
                 Etat : String [4];    {BIN,ASC,BUG,nølib}
                 Size : LongInt;
                 Date : LongInt;
                 Help : String [192];
               END;

Var  Fichier : File;                   { Fichier … analyser }
     Tampon  : String [10];
     Bible   : File;                   { Fichier base de donn‚es temporaire }
     Lgn     : Lin;
     Bib     : File;                   { Fichier base de donn‚es HP }
     Lg      : Ligne;
     Rech    : Ligne;
     Tot_fic : Integer;                { Nb de fichiers dans la Bible }
     Tot_oct : LongInt;                { Compteur de tailles de fichiers }
     Test    : Boolean;                { ! Flag pour tester les prog ! }

     P       : Word;                   { Position courante dans la Bible }
     Touche  : Char;
     Deca    : Byte;                   { D‚calage en lignes pour 80x25 }
     Ordre   : Array [1..8] of 0..8;   { l'ordre des critŠres de TRI }
     NbC     : Word;                   { Nb de fichiers par caractŠre}

Procedure Lit_Ligne (Var F : File;n : Word); { Lit 1 ligne de la Bible }
Begin
  Seek (F,n-1);
  {$i-} BlockRead (F,Lg,1); {$i+}
  if IOresult<>0 then Error(12);
End;

PROCEDURE Dir_Tree (path   : String;   { s/cat … traiter }
                    niv    : Word;     { niv. de profondeur }
                    nbrdir : NivType); { nb de dir restant pour les niv. inf }
Var dta           : ^SearchRec;
    dirlist,dircur,                    { pointeur d‚but de liste, }
    dirlast       : ^Sdir;             { dir. courant & pr‚c‚dent }
    cur_path      : ^Str55;            { zone de travail }
    i,nbr_fic     : Integer;
    nbr_oct       : LongInt;
    DT            : DateTime;
Begin
 New (cur_path); New (Dta);

 dirlist:=Nil; dircur:=Nil; dirlast:=Nil; { Initialisation }
 i:=0; nbr_fic:=0; nbr_oct:=0;
 Cur_Path^:=path+'\*.*';
 nbrdir[niv]:=0;

 FindFirst (Cur_Path^,DIRECTORY,DTA^);   { 1er fichier }

 WHILE Not (DosError + IOResult>0) do    { 1/ Compte tous les fichiers }
 begin
  if Dta^.Attr and $10 <> 0 then
  begin
    if Dta^.Name[1] <> '.' then
    begin
      New (dircur);                                { New s/dir }
      dircur^.nom  := dta^.Name;
      dircur^.suiv := Nil;
      if dirlist = Nil then dirlist      :=dircur; { Enchainement logique }
      if dirlast<> Nil then dirlast^.suiv:=dircur; { de la liste          }
      dirlast:=dircur;
      Inc (nbrdir[niv]);                           { un s/dir en + }
    end;
  end else
  if Test then
  begin                                            { un fichier : HP ? }
   Assign (Fichier,Copy(Cur_Path^,1,Length(Cur_Path^)-3)+dta^.Name);
   {$i-} ReSet (Fichier,1); {$i+}
   if (IOResult=0) and (FileSize (Fichier)<>0) then
   begin
     FillChar (Tampon,SizeOf(Tampon),0); Tampon[0]:=#10;
     {$i-} BlockRead (Fichier,Tampon[1],10); {$i+}
     if (IOResult=0)
     and ((Copy(Tampon,1,4)='%%HP') or
          (Copy(Tampon,1,4)='HPHP')) then { V‚rif de l'entˆte }
     begin
       Inc (nbr_fic);                              { un fichier HP en + }
       nbr_oct:=nbr_oct+dta^.Size;
       FillChar (Lgn.Path,55,#0);
       Lgn.Path:=Path;
       Lgn.Nom:=dta^.Name;
       Lgn.Size:=dta^.Size;           { MAJ de Bible }
       Lgn.Date:=dta^.Time;
       If Copy(Tampon,1,4)='%%HP' then Lgn.Etat:='ASC';
       If Copy(Tampon,1,4)='HPHP' then Lgn.Etat:='BIN';
       If Copy(Tampon,9,2)=#64+#43 then Lgn.Lib:=True else Lgn.Lib:=False;
       {$i-} BlockWrite (Bible,Lgn,1); {$i+} { Ecriture ds Fichier tempo }
       if IOresult<>0 then Error(11);
     end;
   end;
   {$i-} Close (Fichier); {$i+}

  end;
  FindNext (DTA^);
 end;

 Tot_fic:=Tot_fic+nbr_fic;
 Tot_oct:=Tot_oct+nbr_oct;

 WHILE i < niv do                       { 2/ Dessin de l'arbre }
 begin
  if (i<niv-1) AND (nbrdir[i]>1) THEN Write ('³  ');
  if (i<niv-1) AND (nbrdir[i]=1) THEN Write ('   ');
  if (i=niv-1) AND (nbrdir[i]>1) THEN Write ('ÃÄÄ');
  if (i=niv-1) AND (nbrdir[i]=1) THEN Write ('ÀÄÄ');
  Inc (i);
 end;
 Write (LastDir(path)); GotoXY (24,WhereY);
 WriteLn (nbr_fic:4,' ',nbr_oct div 1024:8,' Ko');

 dircur:=dirlist;

 WHILE dircur <> NIL DO                 { 3/ Traitement des s/dir }
 begin
  cur_path^ := path + '\' + dircur^.nom;
  Dir_Tree (cur_path^,niv+1,nbrdir);
  Dec (nbrdir[niv]);
  dirlast := dircur;
  dircur  := dircur^.suiv;
  Dispose (dirlast);
 end;
 Dispose (cur_path);
 Dispose (Dta);
End;

Procedure SCAN; { Û Analyse les sous r‚pertoires et cr‚‚ une Bible Û }
Var nbrdir  : NivType;
    n,nb,l  : Word;
    Find    : Boolean;
    Ok      : Array [1..4000] of Boolean;
BEGIN
  TextAttr:=14+2*16; ClrScr;
  Tot_fic:=0; Tot_oct:=0; Test:=True;

  { 1/ Û Recherche des fichiers HP Û }
  WriteLn;
  WriteLn ('        ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ» ');
  WriteLn ('        º °±² HP Bible ²±° ºÛ');
  WriteLn ('        ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶Û');
  WriteLn ('        º  ->  Analyse ',Path[1],':  ºÛ');
  WriteLn ('        ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼Û');
  WriteLn ('         ßßßßßßßßßßßßßßßßßßßß');
  WriteLn;
  Assign (Bible,DeskTop+'\LISTE_HP.$$$'); {$i-} ReWrite (Bible,SizeOf(Lgn)); {$i+}
  if IOresult<>0 then begin Error(0); Exit; end;

  Dir_Tree (Path,0,nbrdir); WriteLn;
  Close (Bible);
  WriteLn (' Total des fichiers : ',
           Tot_fic:5,' ',Tot_oct div 1024:8,' Ko');

  Repeat
    WriteLn; Write ('  Mise … jour de la Bible HP ? (O/N)');
    Touche:=ReadChar;
  Until Touche in ['O','o','N','n',#27];
  If Touche in ['N','n',#27] then begin Erase (Bible); Exit; end;

  { 2/ Û MAJ de la Bible HP Û }
  WriteLn; WriteLn ('  -> MAJ de la Bible HP ...');
  Assign (Bible,DeskTop+'\LISTE_HP.$$$'); ReSet (Bible,SizeOf(Lgn));
  Assign (Bib,DeskTop+'\HP_Bible'); {$i-} ReSet (Bib); Close (Bib); {$i+}

  If IOresult<>0 then  { Û Bible inexistante -> Cr‚ation Û }
  begin
    WriteLn ('  -> Cr‚ation de la BIBLE.'); nb:=0;
    Assign (Bib,DeskTop+'\HP_Bible'); {$i-} ReWrite (Bib,SizeOf(Lg)); {$i+}
    if IOresult<>0 then begin Error(0); Exit; end;
    For l:=1 to Tot_fic do
    begin
      BlockRead (Bible,Lgn,1);
      With Lg do
        begin
          Nom :=Justi(Lgn.Nom,12);
          Cata:=Justi(LastDir (Lgn.Path),8);
          Aute:=Repet(#0,8);
          Note:=#0#0#0;
          If Lgn.Lib then Id:='LIB' else Id:='NEW';
          Etat:=Justi(Lgn.Etat,4);
          Size:=Lgn.Size;
          Date:=Lgn.Date;
          FillChar (Help,193,0); Help[0]:=#192;
        end;
      GotoXY (1,WhereY); Write ('       Fichier nø',l:4);
      BlockWrite (Bib,Lg,1);  { Ecriture }
    end;
  end else             { Û MAJ Û }
  begin
    Assign (Bib,DeskTop+'\HP_Bible'); ReSet (Bib,SizeOf(Lg));
    nb:=FileSize(Bib);      { nb=nb de fiches d‚j… ds Bible }
    WriteLn ('  -> Nb de fichiers ds la Bible : ',nb);
    For l:=1 to 4000 do Ok[l]:=False; { Aucun fichier trouv‚ }
    For l:=1 to Tot_fic do  { -> Analyse chaque fichier }
    begin
      BlockRead (Bible,Lgn,1); { Prend nom ds HP_Bible.$$$ }
      GotoXY (1,WhereY);
      Write ('  Recherche fichier ',l,'/',Tot_Fic,' = ',Lgn.Nom); ClrEol;
      Find:=False; n:=1;    { -> Recherche ds la HP_Bible }
      While (n<=nb) and (Not Find) do
      begin
        If Ok[n]=False then { Non trouv‚ auparavant }
          begin
            Lit_Ligne (Bib,n); { Lit nom ds HP_Bible }
            If (Justi(Lg.Nom,12)=Justi(Lgn.Nom,12))
            and (Justi(Lg.Cata,8)=Justi(LastDir(Lgn.Path),8)) then
              begin Find:=True; Ok[n]:=True; end; { Trouv‚ = Flagu‚ }
          end;
        Inc (n);
      end;
      If Find=False then { -> Ajouter dans la Bible }
        begin
          Seek (Bib,FileSize(Bib));
          With Lg do
            begin
              Nom :=Justi(Lgn.Nom,12);
              Cata:=Justi(LastDir (Lgn.Path),8);
              Aute:=Repet(#0,8);
              Note:=#0#0#0;
              If Lgn.Lib then Id:='LIB' else Id:='NEW';
              Etat:=Justi(Lgn.Etat,4);
              Size:=Lgn.Size;
              Date:=Lgn.Date;
              FillChar (Help,193,0); Help[0]:=#192;
            end;
          BlockWrite (Bib,Lg,1); { Ecriture }
        end;
    end;
  end;
  WriteLn;
  WriteLn ('  -> Ajout de ',FileSize(Bib)-nb,' fichiers');
  Repeat
    WriteLn ('  Chercher les fichiers MANQUANTS ? (O/N)');
    Touche:=ReadChar;
  Until Touche in ['O','o','N','n'];
  If Touche in ['O','o'] then
  begin
    WriteLn ('  -> Fichiers non retrouv‚s sur DISQUE :');
    For l:=1 to nb do { Analyse les fiches d‚j… ds la bible mais non trouv‚es }
      if Not Ok[l] then
        begin
          Lit_Ligne (Bib,l);
          WriteLn ('     fiche nø',l:4,' = ',Justi(Lg.Nom,12),' ds ',Lg.Cata);
        end;
  end;
  nb:=FileSize(Bib); WriteLn('  -> ',nb,' fichiers dans la Bible.');
  {$i-} Close (Bib); Close (Bible);
        Erase (Bible); {$i+}
  if IOresult<>0 then Error(12);
  Wait_Key;
END;

Procedure STATISTIQUE; { Û Affiche les STATs de la bible Û }
Var Lst : Array [1..50] of Record              { Liste des catalogues }
                             Cata : String[8];
                             Nb   : Word;
                             N_N  : Word;
                             N_AB : Word;
                             N_B  : Word;
                             N_TB : Word;
                             N_E  : Word;
                             Size : LongInt;
                           End;
    Aut : Array [1..99] of Record              { Liste des Auteurs }
                             Nom  : String[8];
                             Nb   : LongInt;
                             Tot  : LongInt;
                           End;
    Lib : Array [1..500] of Word;              { Liste des fiches librairie }
    T_N,T_AB,T_B,T_Tb,T_E : Word;              { les totaux }
    CLUSTER,i,j,l,n,no,nn : Word;
    Tot_Dsk : LongInt;                         { Place v‚ritablement prise }
    Temp       : Record                        { temporaire pour TRI }
                   Nom  : String[8];
                   Nb   : LongInt;
                   Tot  : LongInt;
                 End;
    DT         : DateTime;
    CALEN      : Array [1..12] of Word;
    STAT       : Text;                         { Fichier DOC des STATs }
    Lin        : String;
Begin
  TextAttr:=14+2*16; ClrScr;
  Assign (STAT,DeskTop+'\HP_STAT.PRN'); {$i-} ReWrite (STAT); {$i+}
  If IOresult<>0 then begin Error(0); Exit; end;
  Assign (Bib,DeskTop+'\HP_Bible');
  {$i-} ReSet (Bib,SizeOf(Lg)); Tot_Fic:=FileSize(Bib); {$i+}
  If IOresult<>0 then Exit;
  WriteLn (STAT);
  WriteLn (STAT,'        ÉÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ» ');
  WriteLn (STAT,'        º °±² HP Bible ²±° ºÛ');
  WriteLn (STAT,'        ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶Û');
  WriteLn (STAT,'        º  -> STATISTIQUES ºÛ');
  WriteLn (STAT,'        ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼Û');
  WriteLn (STAT,'         ßßßßßßßßßßßßßßßßßßßß');
  WriteLn (STAT);
  For i:=1 to 50 do { Init. }
    With Lst[i] do
      begin Cata:=''; Nb:=0; N_N:=0; N_AB:=0; N_B:=0; N_TB:=0; N_E:=0; end;
  For i:=1 to 99 do begin Aut[i].Nom:=''; Aut[i].Nb:=0; Aut[i].Tot:=0; end;
  For i:=1 to 12 do CALEN[i]:=0;
  For i:=1 to 500 do Lib[i]:=0;
  T_N:=0; T_AB:=0; T_B:=0; T_TB:=0; T_E:=0;
  Tot_Dsk:=0; CLUSTER:=0; n:=1; no:=1; nn:=1; l:=1; Tot_oct:=0;

  ASM { Taille d'un CLUSTER }
    MOV AX,3600h
    MOV DX,0h
    INT 21h
    MUL CX
    MOV CLUSTER,AX
  End;

  While l<>Tot_Fic do { Analyse tous les fichiers }
    begin
      Lit_Ligne (Bib,l); Test:=False; Inc(Tot_Oct,Lg.size);
      If Lg.Size<CLUSTER then Inc(Tot_Dsk,CLUSTER) else Inc(Tot_Dsk,Lg.Size);
      UnPackTime (Lg.Date,DT); Inc (CALEN[DT.month]);
      If Lg.Id='LIB' then begin Lib[nn]:=l; Inc(nn); end;
      { MAJ des totaux }
      If Lg.Note=#0#0  then Inc(T_N);
      If Lg.Note='AB'  then Inc(T_AB);
      If Lg.Note='B'#0 then Inc(T_B);
      If Lg.Note='TB'  then Inc(T_TB);
      If Lg.Note='E!'  then Inc(T_E);

      For i:=1 to n do   { Recherche le nom du catalogue }
        if Lg.Cata=Lst[i].Cata then
          begin          { Trouv‚ }
            Test:=True;
            Inc(Lst[i].Nb); Inc(Lst[i].Size,Lg.Size);
            if Lg.Note=#0#0  then Inc(Lst[i].N_N);
            if Lg.Note='AB'  then Inc(Lst[i].N_AB);
            if Lg.Note='B'#0 then Inc(Lst[i].N_B);
            if Lg.Note='TB'  then Inc(Lst[i].N_TB);
            if Lg.Note='E!'  then Inc(Lst[i].N_E);
            i:=n;
          end;
      If Not Test then   { Sinon cr‚ation du catalogue }
        begin
          Lst[n].Cata:=Lg.Cata;
          Lst[n].Nb:=1;
          Lst[n].Size:=Lg.Size;
          if Lg.Note=#0#0  then Lst[n].N_N :=1;
          if Lg.Note='AB'  then Lst[n].N_AB:=1;
          if Lg.Note='B'#0 then Lst[n].N_B :=1;
          if Lg.Note='TB'  then Lst[n].N_TB:=1;
          if Lg.Note='E!'  then Lst[n].N_E :=1;
          Inc(n);
        end;
      Test:=False;
      For i:=1 to no do  { Recherche le nom de l'auteur }
        if UnJusti(Lg.Aute)=UnJusti(Aut[i].Nom) then
          begin Test:=True; Inc(Aut[i].Nb); Inc(Aut[i].Tot,Lg.Size); end;
      If (Not Test) and (UnJusti(Lg.Aute)<>'') then { Un nouveau }
        begin
          Aut[no].Nom:=UnJusti(Lg.Aute); Aut[no].Nb:=1;
          Aut[no].Tot:=Lg.Size; Inc(no);
        end;

      Inc(l);
    end;

  WriteLn (STAT,'  CATALOGUE  ???  AB  B  TB  !E!  Nb f Taille');
  WriteLn (STAT,Repet('Ä',51));
  For i:=1 to n-1 do
    With Lst[i] do
      begin
        NUL:=#0; Cata:=UnJusti(Cata); NUL:='.';
        Write (STAT,' . ',Justi(Cata,8),'..');
        If N_N <>0 then Write (STAT,N_N :3,'.') else Write (STAT,'....');
        If N_AB<>0 then Write (STAT,N_AB:3,'.') else Write (STAT,'....');
        If N_B <>0 then Write (STAT,N_B :3,'.') else Write (STAT,'....');
        If N_TB<>0 then Write (STAT,N_TB:3,'.') else Write (STAT,'....');
        If N_E <>0 then Write (STAT,N_E :3,'.') else Write (STAT,'....');
        Write (STAT,'.',Nb:4,' ');
        If Size>999999 then
          Write(STAT,Size div 1024:4,'Ko') else Write(STAT,Size:6);
        WriteLn (STAT,' ',Size/Tot_oct*100:2:0,'%');
      end;
  WriteLn (STAT,Repet('Í',51)); { TOTAUX }
  Write (STAT,'  TOTAUX ',n-1:2,' ',T_N :4,' ',
                                    T_AB:3,' ',
                                    T_B :3,' ',
                                    T_TB:3,' ',
                                    T_E :3,'  ',Tot_Fic:4,' ');
  If Tot_oct>999999 then WriteLn (STAT,Tot_oct div 1024:4,'Ko(ä)')
  else WriteLn (STAT,Tot_oct:6,'(ä)');
  Write (STAT,'  TOTAUX     ',T_N /Tot_Fic*100:2:0,'% ',
                              T_AB/Tot_Fic*100:2:0,'% ',
                              T_B /Tot_Fic*100:2:0,'% ',
                              T_TB/Tot_Fic*100:2:0,'% ',
                              T_E /Tot_Fic*100:2:0,'%       ');
  If Tot_Dsk>999999 then WriteLn (STAT,Tot_Dsk div 1024:4,'Ko(DOS)')
  else WriteLn (STAT,Tot_Dsk:6,'(DOS)');
  WriteLn (STAT,Repet('Í',51)); WriteLn (STAT);

  WriteLn (STAT,'  ****** TOP DES PROGRAMMEURS : ******'); WriteLn (STAT);
  For i:=1 to Pred(no-1) do { Tri par ordre d‚croissant }
    For j:=Succ(i) to no-1 do
      if Aut[i].Nb<Aut[j].Nb then
        begin
          NUL:=#0; Aut[i].Nom:=UnJusti(Aut[i].Nom);
                   Aut[j].Nom:=UnJusti(Aut[j].Nom); NUL:=#32;
          temp.Nom:=Aut[i].Nom;
          temp.Nb :=Aut[i].Nb;
          temp.Tot:=Aut[i].Tot;
          Aut[i]:=Aut[j];
          Aut[j].Nom:=temp.Nom;
          Aut[j].Nb :=temp.Nb;
          Aut[j].Tot:=temp.Tot;
        end;
  For i:=1 to no-1 do       { Ecriture }
    WriteLn (STAT,'  ',i:2,'. ',Justi(Aut[i].Nom,8),
             ' avec ',Aut[i].Nb:2,' objets(',Aut[i].Tot:6,'c)');

  WriteLn (STAT);
  WriteLn (STAT,'  ****** REFERENCE DES LIBRAIRIES : ******'); WriteLn (STAT);
  WriteLn (STAT,'fiche NOM         CATALOGUE AUTEUR     TAILLE Nølib');
  WriteLn (STAT,'      ÄÄÄÄÄÄÄÄÄÄÄÄ ÄÄÄÄÄÄÄÄ ÄÄÄÄÄÄÄÄ   ÄÄÄÄÄÄ ÍÍÍÍÍ');
  For i:=1 to nn-1 do
    begin
      Lit_Ligne (Bib,Lib[i]);
      NUL:=#0;  Lg.Nom :=UnJusti(Lg.Nom );
                Lg.Cata:=UnJusti(Lg.Cata);
                Lg.Aute:=UnJusti(Lg.Aute);
                Lg.Etat:=UnJusti(Lg.Etat); NUL:=#32;
      WriteLn (STAT,Lib[i]:4,'. ',
                    Justi(Lg.Nom,12),' ',
                    Justi(Lg.Cata,8),' ',
                    Justi(Lg.Aute,8),' ',
                    IntToStr(Lg.Size),' ',
                    Justi(Lg.Etat,4));
    end;
  WriteLn (STAT,'      ÄÄÄÄÄÄÄÄÄÄÄÄ ÄÄÄÄÄÄÄÄ ÄÄÄÄÄÄÄÄ   ÄÄÄÄÄÄ ÍÍÍÍÍ');
  WriteLn (STAT,'      Nombre de librairies : ',nn-1:4,
                '  soit ',(nn-1)/Tot_Fic*100:2:1,' %');
  Close (Bib);

  WriteLn (STAT);
  WriteLn (STAT,'  ****** CALENDRIER 19XX ******'); WriteLn (STAT);
  WriteLn (STAT,'JAN FEV MAR AVR MAI JUI JUI AOU SEP OCT NOV DEC');
  WriteLn (STAT,Repet('Ä',47));
  For i:=1 to 12 do
    Write (STAT,CALEN[i]:3,' ');
  WriteLn (STAT);
  For i:=1 to 12 do
    Write (STAT,CALEN[i]/Tot_Fic*100:2:0,'% ');

  Close (STAT);             { AFFICHAGE … l'‚cran }
  NUL := #0;                { Remet la valeur initiale }
  {$i-} Assign (STAT,DeskTop+'\HP_STAT.PRN'); ReSet (STAT); {$i+}
  Repeat
    ReadLn (STAT,Lin);
    Write (Lin);
    if (Length(Lin)<=50) and (WhereY<>NbLn-12) then WriteLn;

    if (WhereY=NbLn-12) and (WhereX>1) then { Nouvelle page }
      begin Wait_Key; ClrScr; GotoXY (1,1); end;
  Until EOF(STAT);
  Close (STAT);
  Wait_Key;
End;

Procedure Formulaire; { Û Affiche la feuille de formulaire Û }
Var DT : DateTime;
Begin
  With Lg do
    begin
      Button   (' Nom   ',2,02-Deca,14+4*16,1+2*16);
      WriteStr (11,02-Deca,Justi(Nom,12),7*16);

      Button   (' Catalogue ',25,2-Deca,14+4*16,1+2*16);
      WriteStr (38,02-Deca,Justi(Cata,8),15+2*16);

      Button   (' Auteur ',2,04-Deca,14+4*16,1+2*16);
      WriteStr (13,04-Deca,Justi(Aute,8),14);

      WriteStr (22,04-Deca,IntToStr(Size)+' octets',14+2*16);
      UnPackTime (Date,DT);
      WriteStr (42,04-Deca,NumStr(DT.day,2)+'/'
                          +NumStr(DT.month,2)+'/'
                          +NumStr(DT.year-1900,2),14+2*16);
      Button   (' Note ',2,06-Deca,14+4*16,1+2*16);
      WriteStr (10,06-Deca,Justi(Note,2)+' (AB/B/TB/E!)',14+2*16);

      Button   (' ID ',26,06-Deca,14+4*16,1+2*16);
      WriteStr (32,06-Deca,Id,14+2*16);
      WriteStr (36,06-Deca,Etat,14+2*16);

      WriteStr (41,06-Deca,NumStr(P,4)+'/'+NumStr(Tot_Fic,4),14+4*16);

      WriteStr (2,08-Deca,Copy(Help,  1,48),7);
      WriteStr (2,09-Deca,Copy(Help, 49,48),7);
      WriteStr (2,10-Deca,Copy(Help, 97,48),7);
      WriteStr (2,11-Deca,Copy(Help,145,48),7);
    end;
End;

Procedure AIDE_SGBD (D : Integer); { Û Aide pour le formulaire Û }
Begin
  if NbLn<>25 then WriteStr (1,D,Repet('Í',51),14+2*16);

  Button   (' '+#27#26+','+#18+',HOME,FIN ',2,D+2,14+4*16,1+2*16);
  WriteStr (19,D+2,'Pour se d‚placer',14+2*16);

  Button   (' E ',2,D+4,14+4*16,1+2*16);
  WriteStr (7,D+4,'Modifier le formulaire',14+2*16);

  Button   (' S ',2,D+6,14+4*16,1+2*16);
  WriteStr (7,D+6,'Supprimer le choix',14+2*16);

  Button   (' R ',2,D+8,14+4*16,1+2*16);
  WriteStr (7,D+8,'Rechercher des donn‚es dans la BIBLE HP',14+2*16);

  Button   (' T ',2,D+10,14+4*16,1+2*16);
  WriteStr (7,D+10,'Trier la bible suivant un critŠre',14+2*16);

  Button   (' I ',2,D+12,14+4*16,1+2*16);
  WriteStr (7,D+12,'Imprimer tout ou la s‚lection',14+2*16);

  Button   ('Pg'#24,2,D+14,14+4*16,1+2*16);
  WriteStr (7,D+14,'Envoyer le fichier s‚lectionn‚ via RS232',14+2*16);
End;

Procedure EDIT (Var Nu : Byte); { Û Edition des champs en mode formulaire Û }
Begin
  CursON;
  Case Nu of
    0 : begin { Champ Nom  }
          TextAttr:=7*16; Alpha:=Lg.Nom;
          Saisie (11,02-Deca,12,S_Type_Chaine,'');
          Lg.Nom:=Justi(Alpha,12);
        end;
    1 : begin { Champ Cata }
          TextAttr:=11+2*16; Alpha:=Lg.Cata;
          Saisie (38,02-Deca,08,S_Type_Chaine,'');
          Lg.Cata:=Justi(Alpha,8);
        end;
    2 : begin { Champ Aute }
          TextAttr:=14; Alpha:=Lg.Aute;
          Saisie (13,04-Deca,08,S_Type_Chaine,'');
          Lg.Aute:=Justi(Alpha,8);
        end;
    3 : begin { Champ Note : AB,B,TB,E! }
          TextAttr:=14+2*16; Alpha:=Lg.Note;
          Saisie (10,06-Deca,02,S_Type_Chaine,'');
          Lg.Note:=Justi(Alpha,2);
        end;
    4 : begin { Champ Id   : LIB,RPL,EXT,ASM,GRB }
          TextAttr:=14+2*16; Alpha:=Lg.Id;
          Saisie (32,06-Deca,03,S_Type_Chaine,'');
          Lg.Id:=Justi(Alpha,3);
        end;
    5 : begin { Champ Etat : BIN,ASC,BUG }
          TextAttr:=14+2*16; Alpha:=Lg.Etat;
          Saisie (36,06-Deca,04,S_Type_Chaine,'');
          Lg.Etat:=Justi(Alpha,4);
        end;
    6 : begin { Champ 1ere ligne Help }
          TextAttr:=7; Alpha:=Copy(Lg.Help,1,48);
          Saisie (2,08-Deca,48,S_Type_Chaine,'');
          Lg.Help:=Justi(Alpha,48)+Copy(Lg.Help,49,3*48);
        end;
    7 : begin { Champ 2ere ligne Help }
          TextAttr:=7; Alpha:=Copy(Lg.Help,49,48);
          Saisie (2,09-Deca,48,S_Type_Chaine,'');
          Lg.Help:=Copy(Lg.Help,1,48)+Justi(Alpha,48)+Copy(Lg.Help,97,2*48);
        end;
    8 : begin { Champ 3ere ligne Help }
          TextAttr:=7; Alpha:=Copy(Lg.Help,97,48);
          Saisie (2,10-Deca,48,S_Type_Chaine,'');
          Lg.Help:=Copy(Lg.Help,1,2*48)+Justi(Alpha,48)+Copy(Lg.Help,145,48);
        end;
    9 : begin { Champ 4ere ligne Help }
          TextAttr:=7; Alpha:=Copy(Lg.Help,145,48);
          Saisie (2,11-Deca,48,S_Type_Chaine,'');
          Lg.Help:=Copy(Lg.Help,1,3*48)+Justi(Alpha,48);
        end;
  End;
  CursOFF;
End;

Procedure CHP_RECH (Var Nu : Byte); { Û Demande les critŠres de recherche Û }
Begin
  CursON;
  Case Nu of
    0 : begin { Champ Nom  }
          TextAttr:=7*16; Alpha:=Rech.Nom;
          Saisie (11,02-Deca,12,S_Type_Chaine,'');
          Rech.Nom:=Majus(Alpha);
        end;
    1 : begin { Champ Cata }
          TextAttr:=11+2*16; Alpha:=Rech.Cata;
          Saisie (38,02-Deca,08,S_Type_Chaine,'');
          Rech.Cata:=Majus(Alpha);
        end;
    2 : begin { Champ Aute }
          TextAttr:=14; Alpha:=Rech.Aute;
          Saisie (13,04-Deca,08,S_Type_Chaine,'');
          Rech.Aute:=Alpha;
        end;
    3 : begin { Champ Note : AB,B,TB,E! }
          TextAttr:=14+2*16; Alpha:=Rech.Note;
          Saisie (10,06-Deca,02,S_Type_Chaine,'');
          Rech.Note:=Alpha;
        end;
    4 : begin { Champ Id   : LIB,RPL,EXT,ASM,GRB }
          TextAttr:=14+2*16; Alpha:=Rech.Id;
          Saisie (32,06-Deca,03,S_Type_Chaine,'');
          Rech.Id:=Alpha;
        end;
    5 : begin { Champ Etat : NEW,BIN,ASC,BUG }
          TextAttr:=14+2*16; Alpha:=Rech.Etat;
          Saisie (36,06-Deca,04,S_Type_Chaine,'');
          Rech.Etat:=Alpha;
        end;
    6 : begin { Champ 1ere ligne Help }
          TextAttr:=7; Alpha:=Rech.Help;
          Saisie (2,08-Deca,48,S_Type_Chaine,'');
          Rech.Help:=Alpha;
        end;
  End;
  CursOFF;
End;

Procedure ENVOYER; { Û Transfert d'un fichier en Xmodem Û }
Begin
  ClrScr;
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
  if not Port_Open (Port) then begin Error(9); Exit; end;
  InitCRC;
  TextAttr:=14+6*16;
  WriteLn; WriteLn (' Fichier ',Lg.Nom);
  TextAttr:=14+2*16; ClrEol;
  {$i-} ChDir (Ori+'\'+Lg.Cata); {$i+}
  if IOresult <> 0 then begin WriteLn (' -> introuvable ! '); end
  else
    begin
      Filename:=Lg.Nom;
      Flag := TxyModem(Port,Filename,Buffer,OneKflag,BatchFlag);
      if Flag and BatchFlag then { Fin du Batch }
        begin
          (* BATCH -> Send fichier vide *)
          Filename := '';
          Flag := TxyModem(Port,Filename,Buffer,OneKflag,BatchFlag);
        end;
    end;
  Close_Com (Port);
  Sound (1500); Delay (5); NoSound;
  WriteLn; WriteLn (' Une touche pour continuer ...');
  Wait_Key;
  ClrScr; If NbLn<>25 then Aide_SGBD (15);
End;

Procedure GO (L : Word); { Positionne dans le tb de TRI }
Var X,Y,H : Word;
Begin
  Y:=(L-1) div (48*NbC);
  X:=Round(0.01+48*Frac((L-1) / (48*NbC)));
  if NbLn=25 then GotoXY (2+X,2+Y)
  else GotoXY (2+X,4+Y);
End;

Function Lit_Champ(n:Word):String; { Û Retourne les champs pour TRI Û }
Var L   : Ligne;
    DT  : DateTime;
    D   : LongInt;
    TRI : String; { Ligne servant au TRI }
    C   : Byte;
    Nb_C: Word;
    CC  : Char;
Begin
  TRI:='';
  If n>0 then
    begin
      Seek (Bib,n-1);
      BlockRead (Bib,L,1);
      for c:=1 to 8 do { respecte ordre du TRI des champs }
        begin
          if Ordre[1]=c then TRI:=TRI+L.Nom;
          if Ordre[2]=c then TRI:=TRI+L.Cata;
          if Ordre[3]=c then TRI:=TRI+L.Aute;
          if Ordre[4]=c then TRI:=TRI+L.Note;
          if Ordre[5]=c then TRI:=TRI+L.Id  ;
          if Ordre[6]=c then TRI:=TRI+L.Etat;
          if Ordre[7]=c then TRI:=TRI+IntToStr(L.Size);
          if Ordre[8]=c then begin
                               UnPackTime (L.Date,DT);
                               D:=100000*(DT.year-1900)+1000*DT.month+DT.day;
                               TRI:=TRI+IntToStr(D);
                             end;
        end;
        Lit_Champ:=TRI;
    end;
End;

Procedure Swap_Champ(n:Word;nn:Word); { Û Echange 2 lignes de la Bible Û }
Var L1,L2 : Ligne;
Begin
  if Keypressed and (ReadKey=#27) then begin Test:=False; Exit; end;
  Go (n);  Write (#1);
  Go (nn); Write (#2);
  Seek (Bib,n-1);
  BlockRead (Bib,L1,1);
  Seek (Bib,nn-1);
  BlockRead (Bib,L2,1);
  Seek (Bib,nn-1);
  BlockWrite(Bib,L1,1);
  Seek (Bib,n-1);
  BlockWrite(Bib,L2,1);
  Go (n);  Write ('Û');
  Go (nn); Write ('Û');
End;

Procedure QuickSort(Lo,Hi: Word); { Û TRI par la m‚thode QUICK SORT Û }

  procedure Sort(l,r: Word);
  var i,j,ll : Word;
      x      : String;
  begin
    i:=l; j:=r; ll:=(l+r) DIV 2; x:=Lit_Champ(ll);
    repeat
      while Lit_Champ(i)<x do i:=i+1;
      while x<Lit_Champ(j) do j:=j-1;
      if i<=j then
        begin
          Swap_Champ(i,j); If Test=False then Exit;
          i:=i+1; j:=j-1;
        end;
    until i>j;
    if l<j then Sort(l,j);
    if i<r then Sort(i,r);
  end;

Begin
  Sort(Lo,Hi);
End;

Procedure SGBD; { Û Super Gestionnaire de Base de Donn‚es Û }
Var Enr    : Ligne;
    Ok     : Word;                    { Flag : Pas d'erreur }
    l      : Word;
    Tmp    : File;                    { Fichier temporaire pour SUPPRIMER }
    Key    : Char;
    Chp    : Byte;                    { Nø identifiant le champs de saisie }
    Tb     : Array [1..4000] of Word; { Tb de nø de ligne pour la recherche }
    Tot_Fd : Word;                    { Nb de fichiers trouv‚s }
    SavTot : Word;
    Index  : Word;
    C_Ok   : Array [1..7] of Boolean; { Tb si Champ est un critŠre de rech. }
    T_Ok   : Array [1..7] of Boolean; { Test si champ r‚pond au critŠre }
    Resul  : Boolean;                 { Tous les critŠres sont confirm‚s }
    Nb_C   : Byte;                    { Nb de critŠres }
    Prt    : Text;                    { Fichier destination impression }
    ImpLn  : String;                  { Ligne pour impression }
    DT     : DateTime;
Begin
  Assign (Bib,DeskTop+'\HP_Bible'); {$i-} ReSet (Bib,SizeOf(Lg)); {$i+}
  if IOresult<>0 then Exit;
  CursOFF; ClrScr; if NbLn<>25 then Aide_SGBD (15);
  if NbLn=25 then Deca:=1 else Deca:=0;
  Tot_Fic:=FileSize (Bib); P:=1;

  Repeat
    if Tot_Fic=0 then Exit;
    Lit_Ligne (Bib,P);       { Lecture des donn‚es }
    Formulaire;                { Affiche le formulaire }

    TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                       GotoXY (1,14-Deca); ClrEol;
    Button   (' Editer ',2,13-Deca,14+4*16,1+2*16);
    WriteStr ( 3,13-Deca,'E',15+4*16);
    Button   (' Supprimer ',12,13-Deca,14+4*16,1+2*16);
    WriteStr (13,13-Deca,'S',15+4*16);
    Button   (' Rechercher ',25,13-Deca,14+4*16,1+2*16);
    WriteStr (26,13-Deca,'R',15+4*16);
    Button   (' Trier ',39,13-Deca,14+4*16,1+2*16);
    WriteStr (40,13-Deca,'T',15+4*16);
    WriteStr (48,13-Deca,'...',14+2*16);

    Touche:=ReadChar;
    Case UpCase(Touche) of
     ^A : begin                { Û Aide si mode 25 lignes Û }
            if NbLn=25 then
              begin
                ClrScr;
                Aide_SGBD (-1);
                Repeat Until ReadChar=^A;
                ClrScr;
              end;
          end;
     ^B : P:=1;                { Û Home Û }
     ^F : P:=Tot_Fic;          { Û Fin  Û }
     ^E : begin Inc(P); if P>Tot_Fic then P:=Tot_Fic; end; { Û Up   Û}
     ^X : begin Dec(P); if P<1 then P:=1; end;             { Û Down Û}
     'E': begin                { Û EDITER Û }
            Button   (' Editer ',2,13-Deca,15+12*16,1+2*16);
            S_initialisation;  { Init. pour la saisie }
            Chp:=0;            { Nø identifiant le champs }
            Repeat
              EDIT (Chp);      { Demande de saisir }
              if S_B_UPP  then begin Dec(Chp); if Chp<0 then Chp:=9; end;
              if S_B_DOWN then begin Inc(Chp); if Chp>9 then Chp:=0; end;
            Until (S_ABANDON=True) and (S_B_UPP=FALSE) and (S_B_DOWN=FALSE);
            TextAttr:=14+2*16; { Confirmation }
            GotoXY (1,13-Deca); ClrEol;
            GotoXY (1,14-Deca); ClrEol;
            Button   (' '+#17+'ÄÙ Sauver ',6,13-Deca,14+4*16,1+2*16);
            WriteStr (7,13-Deca,#17+'ÄÙ',15+4*16);
            Button   (' <ESC> Annuler ',30,13-Deca,14+4*16,1+2*16);
            WriteStr (31,13-Deca,'<ESC>',15+4*16);
            Repeat
              Key:=ReadChar;
            Until Key in [#13,#27];
            if Key=#13 then    { Sauvegarde la saisie }
              begin
                Enr:=Lg; Seek (Bib,P-1); {$i-} BlockWrite (Bib,Enr,1); {$i+}
                if IOresult<>0 then begin Error(0); Exit; end;
              end;
          end;
     'S': begin                { Û Supprimer Û }
            TextAttr:=14+2*16; { Confirmation }
            GotoXY (1,13-Deca); ClrEol;
            GotoXY (1,14-Deca); ClrEol;
            Button   (' '+#17+'ÄÙ Supprimer ',6,13-Deca,14+4*16,1+2*16);
            WriteStr (7,13-Deca,#17+'ÄÙ',15+4*16);
            Button   (' <ESC> Annuler ',30,13-Deca,14+4*16,1+2*16);
            WriteStr (31,13-Deca,'<ESC>',15+4*16);
            Repeat
              Key:=ReadChar;
            Until Key in [#13,#27];
            If Key=#13 then    { Suppression }
              begin
                Assign (Tmp,DeskTop+'\HP_Bible.$$$');
                {$i-} ReWrite (Tmp,SizeOf(Lg)); {$i+}
                if IOresult<>0 then begin Error(0); Exit; end;
                For l:=1 to P-1 do
                  begin
                    Lit_Ligne (Bib,l);
                    BlockWrite (Tmp,Lg,1,Ok);
                    if Ok<>1 then begin Error(11); Exit; end;
                  end;
                For l:=P+1 to Tot_Fic do
                  begin
                    Lit_Ligne (Bib,l);
                    BlockWrite (Tmp,Lg,1,Ok);
                    if Ok<>1 then begin Error(11); Exit; end;
                  end;
                {$i-} Close (Bib);
                      Erase (Bib);
                      Close (Tmp);
                Rename (Tmp,DeskTop+'\HP_Bible'); {$i+}
                if IOresult<>0 then Error(12);
                If P=Tot_Fic then P:=P-1; { Posi-1 car enlŠve derniŠre ligne }

                Assign (Bib,DeskTop+'\HP_Bible');
                {$i-} ReSet (Bib,SizeOf(Lg)); {$i+}
                if IOResult<>0 then Exit;
                Tot_Fic:=FileSize (Bib);
              end;
          end;
     'R': begin                { Û Rechercher Û }
            ClrScr; Nb_C:=0; For Index:=1 to 4000 do Tb[Index]:=0;
            For l:=1 to 7 do begin C_Ok[l]:=False; T_Ok[l]:=False; end;
            FillChar (Lg,SizeOf(Lg),0); { Feuille vierge }
            Formulaire;
            TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                               GotoXY (1,14-Deca); ClrEol;
            Button   (' <ESC> FIN DE SAISIE ',6,13-Deca,14+4*16,1+2*16);
            WriteStr (7,13-Deca,'<ESC>',15+4*16);
            Rech:=Lg;          { Feuille de recherche vierge }
            S_initialisation;  { Init. pour la saisie }
            Chp:=0;            { Nø identifiant le champs }
            Repeat
              CHP_RECH (Chp);  { Demande de saisir }
              if S_B_UPP  then begin Dec(Chp); if Chp<0 then Chp:=6; end;
              if S_B_DOWN then begin Inc(Chp); if Chp>6 then Chp:=0; end;
            Until (S_ABANDON=True) and (S_B_UPP=FALSE) and (S_B_DOWN=FALSE);
            With Rech do       { Regarde si Champ est un critŠre }
              begin
                if Help[1]=' ' then Help:=Repet(#0,192); { si Help vide }
                if Nom <>'' then begin C_Ok[1]:=True; Inc(Nb_C); end;
                if Cata<>'' then begin C_Ok[2]:=True; Inc(Nb_C); end;
                if Aute<>'' then begin C_Ok[3]:=True; Inc(Nb_C); end;
                if Note<>'' then begin C_Ok[4]:=True; Inc(Nb_C); end;
                if Id  <>'' then begin C_Ok[5]:=True; Inc(Nb_C); end;
                if Etat<>'' then begin C_Ok[6]:=True; Inc(Nb_C); end;
                if Help<>'' then begin C_Ok[7]:=True; Inc(Nb_C); end;
              end;
            TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                               GotoXY (1,14-Deca); ClrEol;
            Button   (' '+#17+'ÄÙ RECHERCHER ',6,13-Deca,14+4*16,1+2*16);
            WriteStr (7,13-Deca,#17+'ÄÙ',15+4*16);
            Button   (' <ESC> Annuler ',30,13-Deca,14+4*16,1+2*16);
            WriteStr (31,13-Deca,'<ESC>',15+4*16);
            Repeat
              Key:=ReadChar;
            Until Key in [#13,#27];
            if Key=#13 then    { RECHERCHE }
              begin
                P:=1; SavTot:=Tot_Fic; Seek (Bib,0);
                For Index:=1 to Tot_Fic do
                  begin
                    WriteStr (41,06-Deca,NumStr(Index,4)+'/'+
                                         NumStr(Tot_Fic,4),14+4*16);
                    Lit_Ligne (Bib,Index);     { Lecture des donn‚es }
                                               { Les tests ... }
                    With Rech do
                      begin
                        if C_Ok[1] then T_Ok[1]:=Pos(Nom ,Lg.Nom )<>0;
                        if C_Ok[2] then T_Ok[2]:=Pos(Cata,Lg.Cata)<>0;
                        if C_Ok[3] then T_Ok[3]:=Pos(Aute,Lg.Aute)<>0;
                        if C_Ok[4] then T_Ok[4]:=Pos(Note,Lg.Note)<>0;
                        if C_Ok[5] then T_Ok[5]:=Pos(Id  ,Lg.Id  )<>0;
                        if C_Ok[6] then T_Ok[6]:=Pos(Etat,Lg.Etat)<>0;
                        if C_Ok[7] then T_Ok[7]:=Pos(Help,Lg.Help)<>0;
                      end;
                    if Nb_C=1 then { Test d'1 seul critŠre }
                      begin
                        Resul:=False; l:=1;
                        While Not T_Ok[l] and (l<8) do Inc(l);
                        if T_Ok[l] and (l<=7) then Resul:=True;
                      end
                    else           { "Additionne" les tests }
                     begin
                        Resul:=True;
                        For l:=1 to 7 do
                          if C_Ok[l] then Resul:=Resul AND T_Ok[l];
                     end;
                    If Resul then begin Tb[P]:=Index; Inc(P); end; { OK ! }

                    If P=4000 then { Tableau de recherche satur‚ ! }
                      begin Sound (3000); Delay (2); NoSound; Index:=Tot_Fic; end;
                  end;
                Tot_Fd:=P-1;      { Nb de fichiers trouv‚s }
                if Tot_Fd<>0 then { Des fichiers trouv‚s ! }
                  begin
                    SavTot:=Tot_Fic; Tot_Fic:=Tot_Fd; P:=1;
                    Repeat
                      TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                                         GotoXY (1,14-Deca); ClrEol;
                      Button   (' <HOME,'#24','#25',FIN> ',2,13-Deca,14+4*16,1+2*16);
                      Button   (' <Pg'#24'> ENVOYER ',20,13-Deca,14+4*16,1+2*16);
                      WriteStr (21,13-Deca,'<Pg'#24'>',15+4*16);
                      Button   (' <S> EFFACER ',37,13-Deca,14+4*16,1+2*16);
                      WriteStr (38,13-Deca,'<S>',15+4*16);
                      Lit_Ligne (Bib,Tb[P]);     { Lecture des donn‚es }
                      Formulaire;                { Affiche le formulaire }
                      Key:=UpCase(ReadChar);
                      Case Key of
                        ^E : begin       { Up }
                               Inc(P); if P>Tot_Fic then P:=Tot_Fic;
                             end;
                        ^X : begin       { Down }
                               Dec(P); if P<1 then P:=1;
                             end;
                        ^B : P:=1;       { Home }
                        ^F : P:=Tot_Fic; { Fin  }
                        ^Y : begin       { Envoyer via RS232 }
                               ENVOYER; ClrScr;
                             end;
                        'S': begin       { Supprimer la s‚lection }
                               TextAttr:=14+2*16; { Confirmation }
                               GotoXY (1,13-Deca); ClrEol;
                               GotoXY (1,14-Deca); ClrEol;
                               Button   (' '+#17+'ÄÙ Supprimer ',6,13-Deca,14+4*16,1+2*16);
                               WriteStr (7,13-Deca,#17+'ÄÙ',15+4*16);
                               Button   (' <ESC> Annuler ',30,13-Deca,14+4*16,1+2*16);
                               WriteStr (31,13-Deca,'<ESC>',15+4*16);
                               Repeat
                                 Key:=ReadChar;
                               Until Key in [#13,#27];
                               If Key=#13 then    { Suppression }
                               begin
                                 Assign (Tmp,DeskTop+'\HP_Bible.$$$');
                                 {$i-} ReWrite (Tmp,SizeOf(Lg)); {$i+}
                                 if IOresult<>0 then begin Error(0); Exit; end;
                                 For l:=1 to SavTot do
                                   begin
                                     Resul:=False;
                                     For Index:=1 to Tot_Fd do
                                       if l=Tb[Index] then
                                         begin
                                           GotoXY (1,13-Deca); ClrEol;
                                           GotoXY (1,14-Deca); ClrEol;
                                           WriteStr (7,13-Deca,
                                           ' Effacement du fichier nø'+
                                           IntToStr(l),15+4*16);
                                           Resul:=True;
                                         end;
                                     If Not Resul then
                                       begin
                                         Lit_Ligne (Bib,l);
                                         BlockWrite (Tmp,Lg,1,Ok);
                                         if Ok<>1 then
                                           begin
                                             WriteLn ('Plus de place !');
                                             Wait_Key; Exit;
                                           end;
                                       end;
                                   end;
                                 {$i-} Close (Bib);
                                       Erase (Bib);
                                       Close (Tmp);
                                       Rename (Tmp,DeskTop+'\HP_Bible'); {$i+}
                                 if IOresult<>0 then Error(12);

                                 Assign (Bib,DeskTop+'\HP_Bible');
                                 {$i-} ReSet (Bib,SizeOf(Lg)); {$i+}
                                 if IOResult<>0 then Exit;
                                 Tot_Fic:=FileSize (Bib); P:=1; Exit;
                               end;
                             end;
                      End;
                    Until Key in [#27];
                    Tot_Fic:=SavTot; P:=Tb[P];   { Remet les index }
                  end
                  else
                    begin
                      TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                                         GotoXY (1,14-Deca); ClrEol;
                      WriteStr (18,13-Deca,'! RIEN TROUVE !',15+4*16);
                      Delay (1500);
                    end;
              end;
            if NbLn<>25 then Aide_SGBD (15);
          end;
     'T': begin                { Û Trier Û }
            ClrScr;
            WriteStr (4,2,'-> Choisissez l''ordre des Champs :',14+2*16);
            Button   (' '+#17+'ÄÙ TRIER ',6,13-Deca,14+4*16,1+2*16);
            WriteStr (7,13-Deca,#17+'ÄÙ',15+4*16);
            Button   (' <ESC> Annuler ',30,13-Deca,14+4*16,1+2*16);
            WriteStr (31,13-Deca,'<ESC>',15+4*16);
            For Index:=1 to 7 do Ordre[Index]:=0;
            Index:=1;
            Repeat
              Button   (' <'+Chr(48+Ordre[1])+'> Nom ',4,04,14+4*16,1+2*16);
              WriteStr (9,04,'N',15+4*16);

              Button   (' <'+Chr(48+Ordre[2])+'> Catalogue ',20,04,14+4*16,1+2*16);
              WriteStr (25,04,'C',15+4*16);

              Button   (' <'+Chr(48+Ordre[3])+'> Auteur ',4,06,14+4*16,1+2*16);
              WriteStr (9,06,'A',15+4*16);

              Button   (' <'+Chr(48+Ordre[7])+'> Taille ',20,06,14+4*16,1+2*16);
              WriteStr (25,06,'T',15+4*16);

              Button   (' <'+Chr(48+Ordre[8])+'> Date ',37,06,14+4*16,1+2*16);
              WriteStr (42,06,'D',15+4*16);

              Button   (' <'+Chr(48+Ordre[4])+'> Note ',4,08,14+4*16,1+2*16);
              WriteStr (10,08,'o',15+4*16);

              Button   (' <'+Chr(48+Ordre[5])+'> Id ',20,08,14+4*16,1+2*16);
              WriteStr (25,08,'I',15+4*16);

              Button   (' <'+Chr(48+Ordre[6])+'> Etat ',37,08,14+4*16,1+2*16);
              WriteStr (42,08,'E',15+4*16);

              Repeat
                Key:=UpCase(ReadKey);
              Until Key in [#13,#27,'N','C','A','T','D','O','I','E'];
              if Key='N' then begin Ordre[1]:=Index; Inc(Index); end;
              if Key='C' then begin Ordre[2]:=Index; Inc(Index); end;
              if Key='A' then begin Ordre[3]:=Index; Inc(Index); end;
              if Key='T' then begin Ordre[7]:=Index; Inc(Index); end;
              if Key='D' then begin Ordre[8]:=Index; Inc(Index); end;
              if Key='O' then begin Ordre[4]:=Index; Inc(Index); end;
              if Key='I' then begin Ordre[5]:=Index; Inc(Index); end;
              if Key='E' then begin Ordre[6]:=Index; Inc(Index); end;
            Until (Index=8) or (Key in [#13,#27]);

            if (Index<>1) and (Key<>#27) then
              begin
                ClrScr; CursOFF; Test:=True;
                WriteStr (4,2-Deca,'Patientez : TRI en cours ...',14+2*16);
                WriteStr (4,NbLn-12,'(ESC) pour ABANDONNER.',14+2*16);
                if NbLn=25 then NbC:=Trunc(0.99999999+Tot_Fic/(48*11));
                if NbLn=43 then NbC:=Trunc(0.99999999+Tot_Fic/(48*27));
                if NbLn=50 then NbC:=Trunc(0.99999999+Tot_Fic/(48*33));
                For l:=1 to Tot_Fic do { Affiche la grille }
                  begin
                    Go (l); Write (Chr(176+l mod 3));
                  end;
                QuickSort(1,FileSize(Bib)); { TRI }
                Sound (2440); Delay (5); NoSound;
                CursON; Wait_Key;
              end;
            ClrScr;
            if NbLn<>25 then Aide_SGBD (15);
          end;
     ^Y : begin ENVOYER; end;  { Û Envoyer via RS232 Û }
     'I': begin                { Û Imprimer Û }
            TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                               GotoXY (1,14-Deca); ClrEol;
            Button   (' '#17'ÄÙ TOUT ',2,13-Deca,14+4*16,1+2*16);
            WriteStr (3,13-Deca,#17+'ÄÙ',15+4*16);
            Button   (' <  > LA RECHERCHE ',14,13-Deca,14+4*16,1+2*16);
            Button   (' <ESC> Annuler ',35,13-Deca,14+4*16,1+2*16);
            WriteStr (37,13-Deca,'ESC',15+4*16);
            Repeat
              Key:=ReadChar;
            Until Key in [#13,#27,#32];
            If Key in [#13,#32] then
              begin
                TextAttr:=14+2*16; GotoXY (1,13-Deca); ClrEol;
                                   GotoXY (1,14-Deca); ClrEol;
                WriteStr (2,13-Deca,'IMPRESSION : Cr‚ation du fichier '+
                                    'HP_LISTE.PRN...',15+4*16);
                {$i-} Assign (Prt,DeskTop+'\HP_LISTE.PRN');
                      ReWrite (Prt); {$i+}
                if IOresult<>0 then begin Error(0); Exit; end;
                FillChar(ImpLn,SizeOf(ImpLn),' '); ImpLn[0]:=#0;
                if Key=#13 then Tot_Fd:=Tot_Fic; { Imprime tout la bible }
                For l:=1 to Tot_Fd do
                  begin
                    WriteStr (14,14-Deca,' fichier nø'+
                                        NumStr(l,4)+' = ',14+2*16);
                    if Key=#13 then Lit_Ligne (Bib,l) else Lit_Ligne (Bib,Tb[l]);
                    NUL:=#0;  Lg.Nom :=UnJusti(Lg.Nom );
                              Lg.Cata:=UnJusti(Lg.Cata);
                              Lg.Aute:=UnJusti(Lg.Aute);
                              Lg.Note:=UnJusti(Lg.Note);
                              Lg.Id  :=UnJusti(Lg.Id  );
                              Lg.Etat:=UnJusti(Lg.Etat);
                              Lg.Help:=Replace(Lg.Help,#0,#32); NUL:=#32;
                    WriteStr (32,14-Deca,Justi(Lg.Nom,12),14+2*16);
                    UnPackTime (Lg.Date,DT);

                    If Lg.Help[1]<>NUL then
                      begin
                        Write (Prt,'ÄÄ'+NumStr(l,4)+Repet('Ä',74)+#13+#10);
                        ImpLn:=Lg.Nom+Repet('.',16-Length(Lg.Nom))+
                               Justi(Lg.Cata,16)+
                               ' (c) '+Justi(Lg.Aute,8)+' '+
                               ' ['+Justi(Lg.Note,2)+'] '+
                               Justi(Lg.Id,3)+' '+
                               Justi(Lg.Etat,4)+' '+
                               NumStr(Lg.Size,5)+' '+
                               NumStr(DT.day,2)+'/'+
                               NumStr(DT.month,2)+'/'+
                               NumStr(DT.year-1900,2)+'  '+#13+#10;
                        Write (Prt,ImpLn);
                        ImpLn:=Repet(' ',16)+Copy(Lg.Help,1,48)+#13+#10;
                        Write (Prt,ImpLn);
                        if Lg.Help[49]<>NUL then
                          begin
                            ImpLn:=Repet(' ',16)+Copy(Lg.Help,49,48)+#13+#10;
                            Write (Prt,ImpLn);
                          end;
                        if Lg.Help[97]<>NUL then
                          begin
                            ImpLn:=Repet(' ',16)+Copy(Lg.Help,97,48)+#13+#10;
                            Write (Prt,ImpLn);
                          end;
                        if Lg.Help[145]<>NUL then
                          begin
                            ImpLn:=Repet(' ',16)+Copy(Lg.Help,145,48)+#13+#10;
                            Write (Prt,ImpLn);
                          end;
                      end
                    else
                      begin
                        ImpLn:=Lg.Nom+Repet('.',16-Length(Lg.Nom))+
                               Justi(Lg.Cata,16)+
                               '     '+Justi(Lg.Aute,8)+' '+
                               Repet(' ',10)+
                               Justi(Lg.Etat,4)+' '+
                               NumStr(Lg.Size,5)+' '+
                               NumStr(DT.day,2)+'/'+
                               NumStr(DT.month,2)+'/'+
                               NumStr(DT.year-1900,2)+'  '+#13+#10;
                        Write (Prt,ImpLn);
                      end;
                  end;
              end;
            NUL:=#0; Close (Prt); Wait_Key;
          end;
    End;
  Until Touche=^[;
  CursON; Close (Bib);
End;