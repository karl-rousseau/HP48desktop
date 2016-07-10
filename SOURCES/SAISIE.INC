(***************************************)
(** Saisie d'un champ :  SAISIE . PAS **)
(***************************************)
(** Une cha宯e ou un entier ou reel   **)
(***************************************)

Const  S_Type_chaine       = 1   ;
       S_Type_entier       = 2   ;
       S_Type_reel         = 3   ;
       S_Touche_detr       = #08 ;
       S_Touche_return     = #13 ;
       S_Touche_esc        = #27 ;
       S_Touche_val_def    = #59 ;
       S_Touche_vider      = #63 ;
       S_Touche_debut      = #71 ;
       S_Touche_dir_gauche = #75 ;
       S_Touche_dir_droite = #77 ;
       S_Touche_fin        = #79 ;
       S_Touche_ins        = #82 ;
       S_Touche_del        = #83 ;
       S_TOUCHE_UPP        = #72 ;
       S_TOUCHE_DOWN       = #80 ;

Type   S80                 = String[80];

Var S_Espace80,S_sou80,Alpha : s80;
    S_Caract                 : Char;
    S_Touch_Fonc,S_Abandon   : Boolean;
    Entier                   : Integer;
    Reel                     : Real;
    S_B_UPP,S_B_DOWN         : Boolean;

{ 北 Proc俤ure principale de la SAISIE : 北 }

Procedure SAISIE (S_Horiz,
                  S_Vert,
                  S_Long,
                  S_Type:integer;
                  S_Texte:s80);

Var defaut,insertion,ok    : boolean ;
    curseur,numcar,ascii,i : integer ;
    v_defaut               : s80     ;

 { Les sous-proc俤ures }

 procedure beep;
 begin
   Sound (3000); Delay (1); NoSound;
 end;

 procedure saisir_car(var ch:char);
 begin
   Ch:=ReadKey;
   if keypressed then
   begin
     Ch:=ReadKey;
     S_Touch_Fonc:=true;
   end else
   begin
     S_Touch_Fonc:=false;
     if ch in [S_Touche_detr,S_Touche_esc,S_Touche_return]
              then S_Touch_Fonc:=true;
   end;
   if S_Touch_Fonc then
   begin
     case Ch of
      S_Touche_ESC  : S_Abandon:=True ;
      S_Touche_UPP  : begin
                        S_Abandon:=True ;
                        S_B_UPP:=True;
                      end;
      S_Touche_DOWN : begin
                        S_Abandon:=True ;
                        S_B_DOWN:=True;
                      end;
      Else S_Abandon:=False;
     end;
     if S_Abandon then Exit;
   end;
 end;

 function reel_chaine(r:real;decimales:integer):s80;
 var s:s80;
 begin
   str(r:10:decimales,s);
   while s[1]=' ' do delete (s,1,1);
   reel_chaine:=s;
 end;

 procedure affiche (Texte:s80;longueur:integer);
 begin
   texte:=copy(concat(texte,S_Espace80),1,longueur);
   write (Texte);
 end;

 procedure convertir;
 begin
   case S_Type of
     S_type_entier : str (Entier,Alpha);
     S_type_reel   : Alpha:=reel_chaine(Reel,4);
   end;
 end;

 procedure init_saisie;
 begin
   if length(Alpha) > S_Long
     then v_defaut:=copy(Alpha,1,S_Long)
     else v_defaut:=Alpha;
   S_Abandon:=false;
   S_Touch_Fonc:=true;
   S_Caract:=S_Touche_val_def;
   ascii:=0;
   curseur:=S_Horiz;
   S_B_UPP:=FALSE;
   S_B_DOWN:=FALSE;
 end;

 procedure position;
 begin
   if curseur >=1 then GotoXY (curseur,S_Vert)
                  else beep;
 end;

 procedure affiche_x;
 begin
   GotoXY (S_Horiz+length(S_Texte),S_Vert);
   write (Alpha,copy(S_sou80,1,S_Long-length(Alpha)));
   position;
 end;

 procedure affiche_defaut (info:s80);
 begin
   GotoXY (S_Horiz,S_Vert);
   write (S_Texte);
   curseur:=S_Horiz+length(S_Texte);
   numcar:=0;
   Alpha:=info;
   affiche_x;
   defaut:=true;
 end;

 procedure avancer;
 begin
   if ( numcar < S_Long ) and ( numcar < length(Alpha))
   then begin
     numcar:=succ(numcar);
     curseur:=succ(curseur);
     position;
   end
   else beep;
 end;

 procedure reculer;
 begin
   if numcar > 0
   then begin
     numcar:=pred(numcar);
     curseur:=pred(curseur);
     position;
   end
   else beep;
 end;

 procedure debut_ligne;
 begin
   numcar:=0;
   curseur:=S_Horiz+length(S_Texte);
   position;
 end;

 procedure fin_ligne;
 begin
   numcar:=length(Alpha);
   curseur:=S_Horiz+length(S_Texte)+numcar;
   position;
 end;

 procedure mise_zero;
 begin
   case S_Type of
     S_type_chaine : Alpha :='';
     S_type_entier : Alpha :='0';
     S_type_reel   : Alpha :='0.00';
   end;
   debut_ligne;
   affiche_x;
 end;

 procedure ajouter;
 begin
   if numcar < S_Long
   then begin
     numcar:=succ(numcar);
     curseur:=succ(curseur);
     if defaut then Alpha :='';
     if numcar>length(Alpha)
           then Alpha:=concat(Alpha,S_Caract)
           else Alpha[numcar]:=S_Caract;
     if defaut
     then begin
       affiche_x;
       defaut:=false;
     end
     else begin
       write (Alpha[numcar]);
       position;
     end;
   end
   else beep;
 end;

 procedure inserer;
 begin
   if length(Alpha) < S_Long
   then begin
     numcar:=succ(numcar);
     insert(S_Caract,Alpha,numcar);
     curseur:=succ(curseur);
     affiche_x;
   end
   else beep;
 end;

 procedure supprimer;
 begin
   if succ(numcar) <= length(Alpha)
   then begin
     delete (Alpha,succ(numcar),1);
     affiche_x;
   end
   else beep;
 end;

 procedure detruire;
 begin
   if numcar >=1
   then begin
     delete (Alpha,numcar,1);
     numcar:=pred(numcar);
     curseur:=pred(curseur);
     affiche_x;
   end
   else beep;
 end;

 procedure valider;
 begin
   ok:=false;
   if not S_Touch_Fonc then
   case S_Type of
     S_type_chaine : if ascii > 31 then ok:=true;
     S_type_entier : if ( ascii in [48..57]) or (numcar=0)
                        and (ascii in [43,45])
                     then ok:=true;
     S_type_reel   : if ( numcar = 0 ) and ( ascii in [43,45] )
                     then ok:=true
                     else begin
                       ok:=false;
                       if ascii in [48..57]
                         then ok:=true
                         else if ascii = 46
                           then begin
                             ascii:=pos(char(46),Alpha);
                             if ( ascii=0 )
                             or ( ascii=succ(numcar) )
                             and not insertion
                               then ok:=true;
                           end;
                     end;

   end;
 end;

 procedure affiche_saisie;
 var code:integer;
 begin
   GotoXY (S_Horiz+length(S_Texte),S_Vert);
   textcolor (15);
   case S_Type of
    S_type_chaine : affiche (Alpha,S_Long);
    S_type_entier : begin
                      val(Alpha,Entier,code);
                      write(Entier:S_Long);
                    end;
    S_type_reel   : begin
                      val (Alpha,Reel,code);
                      write(Alpha:S_Long);
                    end;
   end;
   lowvideo;
 end;

{ 北 Instructions de la proc俤ure SAISIE : 北 }

BEGIN
  convertir;
  init_saisie;
  Repeat;
    if S_Abandon then exit;
    if S_Touch_Fonc
    then begin
      insertion:=false;
      defaut:=false;
      case S_Caract of
       S_Touche_vider       : mise_zero;
       S_Touche_debut       : debut_ligne;
       S_Touche_fin         : fin_ligne;
       S_Touche_dir_droite  : avancer;
       S_Touche_dir_gauche  : reculer;
       S_Touche_detr        : detruire;
       S_Touche_ins         : insertion:=true;
       S_Touche_del         : supprimer;
       S_Touche_val_def     : affiche_defaut(v_defaut);
      end;
    end
    else begin
      valider;
      if ok
      then
        if insertion then inserer
                     else ajouter
      else beep;
    end;
    saisir_car(S_Caract);
    ascii:=ord(S_Caract);
  Until S_Caract = S_Touche_return ;
  affiche_saisie;
END;

{ 北 Proc俤ure d'initialisation des Variables pour la SAISIE 北 }

Procedure S_initialisation;
begin
  Alpha:='';
  Reel:=0.0;
  Entier:=0;
  fillchar(S_Espace80,81,' ');
  fillchar(S_sou80,81,' ');
  S_Espace80[0]:=#80;
  S_sou80[0]:=#80;
  lowvideo;
  S_B_UPP:=FALSE;
  S_B_DOWN:=FALSE;
end;

{ 北 Programme principale : 北

Var A : Real;

Begin
  ClrScr; A:=0;
  S_Initialisation;
  Repeat
    Saisie (10,5,6,S_Type_Reel,'1 er  reel : '); A:=Reel;
    If (S_ABANDON=True) and (S_B_UPP=FALSE) and (S_B_DOWN=FALSE) then Exit;
  Until S_B_UPP or S_B_DOWN;
End.}