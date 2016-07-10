(****************)
(*              *)
(*  XYmodem.pas *)
(*              *)
(****************)

Unit XYmodem;

Interface

Uses CommPkg,XYpacket,Crt,DOS;

Procedure TxCAN(Port:Integer);

Function TxyModem(
         Port     : Integer;     (* COM port [1..4] *)
     Var Filename : String;      (* filename buffer *)
     Var Buffer   : BufferType;  (* 1024 byte data buffer *)
         OneKflag : Boolean;     (* use 1K blocks when possible *)
         BatchFlag: Boolean)     (* send filename in packet 0 *)
       : Boolean;

Function RxyModem(
         Port     : Integer;     (* COM port [1..4] *)
     Var Filename : String;      (* filename buffer *)
     Var Buffer   : BufferType;  (* 1024 byte data buffer *)
         NCGbyte  : Byte;        (* NAK, 'C', or 'G' *)
         BatchFlag: Boolean)     (* if TRUE, get filename from packet 0 *)
       : Boolean;

Implementation

Const NAK = $15;
      CAN = $18;

Function Temps:LongInt; { Temps en secondes }
Var HH,MM,SS,CS : Word;
Begin
  GetTime (HH,MM,SS,CS); Temps:=SS+60*MM+3600*HH;
End;

Procedure TxCAN(Port:Integer);
var ch : string;
begin
  FillChar (ch,6,$18); SendString (Port,ch);
end;

Function TxyModem(
         Port     : Integer;     (* COM port [1..4] *)
     Var Filename : String;      (* filename buffer *)
     Var Buffer   : BufferType;  (* 1024 byte data buffer *)
         OneKflag : Boolean;     (* use 1K blocks when possible *)
         BatchFlag: Boolean)     (* send filename in packet 0 *)
         : Boolean;
Label 999;
Var
  i, k       : Integer;
  Code       : Integer;
  Flag       : Boolean;
  Handle     : File;
  c          : Char;
  Packet     : Integer;
  PacketType : Char;
  PacketNbr  : Byte;
  BlockSize  : Word;
  ReadSize   : Word;
  FirstPacket: Word;
  EOTflag    : Boolean;
  CheckSum   : Word;
  Number1K   : Word;      (* Nb de paquets de 1K ( 8 records ) *)
  Number128  : Word;      (* Nb de paquets de 128 octets ( 1 record ) *)
  NCGbyte    : Byte;
  FileBytes  : LongInt;
  RemainingBytes : LongInt;
  EmptyFlag  : Boolean;
  Temp1      : String[20];
  Temp2      : String[20];
  Result     : Word;
  Debut,Fin  : LongInt;
Begin
  Number128 := 0;
  Number1K  := 0;
  NCGbyte   := NAK;
  EmptyFlag := FALSE;
  EOTflag   := FALSE;
  if BatchFlag then
    if (Length(Filename)=0) then EmptyFlag := TRUE;
  if not EmptyFlag then
    begin
      Assign(Handle,Filename); {$i-} Reset(Handle,1); {$i+}
      if IOresult<>0 then
        begin
          WriteLn ('Impossible d''ouvrir '+Filename);
          TxyModem := FALSE; goto 999;
        end;
    end;
  WriteLn ('XYMODEM : Attente du receveur');
  (* Calcule le nb de blocs *)
  if EmptyFlag then
    begin (* fichier vide *)
      Number128 := 0;
      Number1K := 0
    end
  else
    begin (* fichier non vide *)
      FileBytes := FileSize(Handle);
      RemainingBytes := FileBytes;
      if OneKflag then Number1K := FileBytes div 1024
                  else Number1K := 0;
      Number128 := 1 + (FileBytes - 1 - 1024 * Number1K) div 128;
      Str (Number1K,Temp1);
      Str (Number128,Temp2);
      WriteLn ('Paquets : ('+Temp1+'x1Ko) + ('+Temp2+'x128o)');
    end;
  (* Vide tampon de r‚ception [NAK peuvent ˆtre rest‚] *)
  R_Flush (Port);
  (* Attend le d‚but en NAK ou 'C' *)
  if not TxStartup(Port,NCGbyte) then begin TxyModem := FALSE; goto 999; end;
  (* Transmission des PAQUETS *)
  if BatchFlag then FirstPacket := 0 else FirstPacket := 1;
  Debut:=Temps;
  for Packet := FirstPacket to Number1K+Number128 do
    begin
      (* Paquet nø *)
      Str (Packet,Temp1);
      GotoXY (1,WhereY); Write ('Paquet nø' + Temp1);
      (* Fabrique le tampon *)
      if Packet=0 then
        begin (* paquet nø0 *)
          if EmptyFlag then Buffer[0] := 0
          else
            begin (* Fichier non vide *)
              (* Met nom du fichier dans le tampon *)
              BlockSize := 128; k := 0;
              for i:= 1 to Length(Filename) do
                begin Buffer[k] := ord(Filename[i]); k:=k+1; end;
              Buffer[k] := 0;
              (* Met la taille dans la tampon *)
              k:=k+1; Str (FileBytes,Temp1);
              for i := 1 to Length(Temp1) do
                begin Buffer[k] := ord(Temp1[i]); k:=k+1; end;
              (* Vide la fin du tampon *)
              for i := k to 127 do Buffer[i] := 0;
            end
        end
      else
        begin  (* Paquet > 0 *)
          (* DATA Paquet : Utiliser 1K ou 128-byte bloc ? *)
          if BatchFlag and (Packet <= Number1K)
            then BlockSize := 1024 else BlockSize := 128;
          (* Nb d'octets … lire *)
          if RemainingBytes < BlockSize then ReadSize := RemainingBytes
          else ReadSize := BlockSize;
          (* Lit le bloc suivant du fichier *)
          BlockRead(Handle,Buffer,ReadSize,Result);
          RemainingBytes := RemainingBytes - Result;
          if Result <> ReadSize then
            begin
              WriteLn ('EOF inattendu !');
              TxyModem := FALSE; goto 999;
            end;
          (* Rempli le reste du tampon avec ^Z=EOF *)
          if ReadSize < BlockSize then
            for i:= ReadSize to Blocksize do Buffer[i] := $1A;
        end;
      (* Envoi du paquet *)
      if not TxPacket(Port,Packet,BlockSize,Buffer,NCGbyte) then
        begin TxyModem := FALSE; goto 999 end;
      (* Red‚marrage aprŠs paquet nø0 non nul *)
      if (not EmptyFlag) and (Packet=0) then Flag := TxStartup(Port,NCGbyte);
    end;
  (* Fin si Paquet nø0 vide *)
  if EmptyFlag then
    begin
      WriteLn ('-> Batch transfert complet !');
      TxyModem := TRUE; goto 999;
    end;
  (* EOT : Fin de la transmission *)
  Close (Handle);
  if not TxEOT(Port) then
    begin
      WriteLn ('EOT non re‡onnu');
      TxyModem := FALSE; goto 999;
    end;
  WriteLn (' -> Transfert complet !');
  TxyModem := TRUE;
999:
  Fin:=Temps;
  if (Fin-Debut)<>0 then
    begin
      WriteLn (' Total : ',Fin-Debut,' s');
      WriteLn (' Taux : ',FileBytes/(Fin-Debut):4:2,' Octets/s');
    end;
End;

Function RxyModem(
         Port     : Integer;        (* COM port [0..3] *)
     Var Filename : String;         (* filename buffer *)
     Var Buffer   : BufferType;     (* 1024 byte data buffer *)
         NCGbyte  : Byte;           (* NAK, 'C', or 'G' *)
         BatchFlag: Boolean)        (* get filename from packet 0 *)
       : Boolean;
Label 999;
Var
  i, k       : Integer;
  Handle     : File;         (* file Handle *)
  Packet     : Integer;      (* packet index *)
  Code       : Integer;      (* return code *)
  Flag       : Boolean;
  EOTflag    : Boolean;
  Temp       : String[40];
  Result     : Integer;
  FirstPacket: Word;
  PacketNbr  : Byte;
  FileBytes  : LongInt;
  EmptyFlag  : Boolean;
  BufferSize : Word;
  Debut,Fin  : LongInt;

Begin
  EmptyFlag := FALSE;
  EOTflag := FALSE;
  WriteLn ('XYMODEM : Attente de l''envoyeur');
  (* Vide le tampon de r‚ception *)
  R_Flush (Port);
  (* Envoi de NAK ou 'C' *)
  if not RxStartup(Port,NCGbyte) then
    begin RxyModem := FALSE; goto 999; end;
  (* Ouvrir fichier si non Batch *)
  if BatchFlag then FirstPacket := 0
  else
    begin (* non Batch *)
      FirstPacket := 1;
      (* Fichier pour ‚crire *)
      Assign(Handle,Filename); {$i-} Rewrite(Handle,1); {$i+}
      if IOresult<>0 then
        begin
          WriteLn ('Ne peut ouvrir ' + Filename);
          RxyModem := FALSE; goto 999;
        end;
    end;
  (* Reception des paquets *)
  Debut:=Temps;
  for Packet := FirstPacket to 32767 do
    begin
      (* Arrˆt utilisateur ? *)
      if KeyPressed then if ReadKey = #27 then
        begin
           TxCAN(Port);
           WriteLn ('*** ARRET ***');
           RxyModem := FALSE; goto 999
        end;
      (* Paquet nø *)
      Str (Packet,Temp);
      GotoXY (1,WhereY); Write ('Paquet nø' + Temp);
      PacketNbr := Packet AND $00ff;
      (* Reception du prochain paquet *)
      if not RxPacket(Port,Packet,BufferSize,Buffer,NCGbyte,EOTflag) then
        begin RxyModem := FALSE; goto 999; end;
      (* paquet nø0 ? *)
      if Packet = 0 then
        begin (* Paquet = 0 *)
          if Buffer[0] = 0 then
            begin
              WriteLn ('-> Batch transfert complet !');
              RxyModem := TRUE; goto 999;
            end;
          (* Lit le nom du fichier *)
          i := 0;
          k := 1;
          repeat
            Filename[k] := chr(Buffer[i]);
            i := i + 1;
            k := k + 1;
          until Buffer[i] = 0;
          FileName[0] := chr(i);
          (* Lit la taille *)
          i := i + 1;
          k := 1;
          repeat
            Temp[k] := chr(Buffer[i]);
            i := i + 1;
            k := k + 1;
          until Buffer[i] = 0;
          Temp[0] := chr(k - 1);
          Val (Temp,FileBytes,Result);
        end;
    (* Fin si EOT re‡u *)
    if EOTflag then
      begin
        FileBytes:=FileSize (Handle); close(Handle);
        WriteLn (' -> Transfert complet !');
        RxyModem := TRUE; goto 999
      end;
    (* Ecriture du paquet *)
    if Packet = 0 then
      begin
        (* Ouvrir fichier avec le nom en Paquet nø0 *)
        Assign(Handle,Filename); {$i-} Rewrite(Handle,1); {$i+}
        if IOresult<>0 then
          begin
            WriteLn ('Ne peut ouvrir ' + Filename);
            RxyModem := FALSE; goto 999;
          end;
        (* Red‚marrage aprŠs paquet nø0 *)
        Flag := RxStartup(Port,NCGbyte);
      end
    else (* nø Paquet > 0 Ecriture des DATA *)
      BlockWrite(Handle,Buffer,BufferSize)
  end;
999:
  Fin:=Temps;
  if (Fin-Debut)<>0 then
    begin
      WriteLn (' Total : ',Fin-Debut,' s');
      WriteLn (' Taux : ',FileBytes/(Fin-Debut):4:2,' Octets/s');
    end;
End;

End.