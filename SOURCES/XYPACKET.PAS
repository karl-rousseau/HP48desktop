(******************)
(*                *)
(*  XYpacket.PAS  *)
(*                *)
(******************)

Unit XYpacket;

Interface

type BufferType = Array [0..1023] of Byte;

Function TxPacket(Port      :Integer;
                  PacketNbr :Word;
                  PacketSize:Word;
              Var Buffer    :BufferType;
                  NCGbyte   :Byte):Boolean;
Function RxPacket(Port      :Integer;
                  PacketNbr :Word;
              Var PacketSize:Word;
              Var Buffer    :BufferType;
                  NCGbyte   :Byte;
              Var EOTflag   :Boolean):Boolean;
Function RxStartup(Port   :Integer;
               Var NCGbyte:Byte):Boolean;
Function TxStartup(Port   :Integer;
               Var NCGbyte:Byte):Boolean;
Function TxEOT(Port:Integer):Boolean;

Implementation

Uses CommPkg,CRC,Crt;

const MAXTRY = 3;

const SOH = $01;
      STX = $02;
      EOT = $04;
      ACK = $06;
      NAK = $15;
      CAN = $18;

Function TxPacket(Port:Integer;         (* Port nø1..4 *)
                  PacketNbr:Word;       (* Paquet 0,... *)
                  PacketSize:Word;      (* Paquet size 128 ou 1024 *)
              Var Buffer:BufferType;    (* Buffer de 1K *)
                  NCGbyte:Byte)         (* NAK, 'C', ou 'G' *)
                : Boolean;              (* SuccŠs *)
Label FIN;
Var I         : Integer;
    Code      : Integer;
    CheckSum  : Word;
    Attempt   : Word;
    PacketType: Byte;
Begin
  (* Mieux vaut mettre 128 ou 1024 dans PacketSize *)
  if PacketSize = 1024 then PacketType := STX
                       else PacketType := SOH;
  PacketNbr := PacketNbr and $00ff;
  (* make up to MAXTRY attempts to send this packet *)
  for Attempt := 1 to MAXTRY do
    begin
      (* Envoi SOH/STX  *)
      Send(Port,Chr(PacketType));
      (* Envoi paquet # *)
      Send(Port,Chr(PacketNbr));
      (* Envoi le compl‚ment du paquet *)
      Send(Port,Chr(255-PacketNbr));
      (* Envoi des data *)
      CheckSum := 0;
      for i := 0 to PacketSize - 1 do
        begin
          Send(Port,Chr(Buffer[i]));
          (* MAJ checksum *)
          if NCGbyte<>NAK then CheckSum := UpdateCRC(CheckSum, Buffer[i])
          else CheckSum := CheckSum + Buffer[i];
        end;
      (* Envoi du Checksum *)
      if NCGbyte<>NAK then
        begin
          (* Envoi 2 octets CRC *)
          Send(Port, Chr((CheckSum shr 8) and $00ff) );
          Send(Port, Chr(CheckSum and $00ff) );
        end
      else (* NCGbyte = 'C' or 'G' *)
        begin
          (* Envoi 1 octet Checksum *)
          Send(Port, Chr(CheckSum) );
        end;
      (* Pas d'attente du ACK si 'G' *)
      if NCGbyte = Ord('G') then
        begin
           if PacketNbr = 0 then
           TxPacket := TRUE; Goto FIN
        end;
      (* Attend ACK du receveur *)
      Code := Byte(Receive(Port));
      if Code = CAN then
         begin
            WriteLn('STOP du receveur');
            TxPacket := FALSE; Goto FIN;
          end;
      if Code = ACK then begin TxPacket := TRUE; Goto FIN end;
      if Code <> NAK then
          begin
            WriteLn(' Pas synchronis‚ !');
            TxPacket := FALSE; Goto FIN;
          end;
    end;
  (* Ne peut envoyer le paquet ! *)
  WriteLn (' Paquet TIMEOUT .');
  TxPacket := FALSE;
FIN: End;

Function RxPacket(Port:Integer;           (* Port # 0..3 *)
                  PacketNbr:Word;         (* Packet # [0,1,2,...] *)
              Var PacketSize:Word;        (* Packet size (128 or 1024) *)
              Var Buffer:BufferType;      (* 1K buffer *)
                  NCGbyte:Byte;           (* NAK, 'C', or 'G' *)
              Var EOTflag:Boolean)        (* EOT was received *)
                  :Boolean;               (* success / failure *)
Label FIN;
Var
  I            : Integer;
  Code         : Integer;
  Attempt      : Word;
  RxPacketNbr  : Word;
  RxPacketNbrC : Word;
  CheckSum     : Word;
  RxCheckSum   : Word;
  RxCheckSum1  : Word;
  RxCheckSum2  : Word;
  PacketType   : Byte;
Begin
  PacketNbr := PacketNbr AND $00ff;
  for Attempt := 1 to MAXTRY do
    begin
      (* Attente d'un SOH / STX *)
      Code := Byte(Receive(Port));
      case Code of
        SOH: begin
               (* Paquet 128o *)
               PacketType := SOH;
               PacketSize := 128;
             end;
        STX: begin
               (* Paquet 1Ko *)
               PacketType := STX;
               PacketSize := 1024;
             end;
        EOT: begin (* Transfert Ok *)
               Send(Port,Chr(ACK));
               EOTflag := TRUE;
               RxPacket := TRUE; goto FIN
             end;
        CAN: begin
               WriteLn ('Arrˆt de l''envoyeur');
               RxPacket := FALSE; goto FIN
             end;
        else
            begin (* erreur ! *)
              WriteLn ('Attente d''un SOH/STX/EOT/CAN');
              RxPacket := FALSE; goto FIN
            end;
      end;
      (* Re‡ois le paquet # *)
      Code := Byte(Receive(Port));
      RxPacketNbr := $00ff and Code;
      (* Re‡ois 1's complement *)
      Code := Byte(Receive(Port));
      RxPacketNbrC := $00ff and Code;
      (* Re‡ois les data *)
      CheckSum := 0;
      for i := 0 to PacketSize - 1 do
        begin
          Code := Byte(Receive(Port));
          Buffer[i] := Code;
          (* Calcul du CRC ou du checksum *)
          if NCGbyte<>NAK
            then CheckSum := UpdateCRC(CheckSum,Code)
            else CheckSum := (CheckSum + Code) AND $00ff;
        end;
      (* Re‡ois le CRC/checksum *)
      if NCGbyte<>NAK then
        begin
          (* Re‡ois 2 octets CRC *)
          Code := Byte(Receive(Port));
          RxCheckSum1 := Code AND $00ff;
          Code := Byte(Receive(Port));
          RxCheckSum2 := Code AND $00ff;
          RxCheckSum := (RxCheckSum1 SHL 8) OR RxCheckSum2;
        end
      else
        begin
          (* Re‡ois 1 octet checksum *)
          Code := Byte(Receive(Port));
          RxCheckSum := Code AND $00ff;
        end;
      (* Ne pas envoyer ACK si 'G' *)
      if NCGbyte = Ord('G') then begin RxPacket := TRUE; Goto FIN end;
      (* Nø paquet et checksum OK ? *)
      if (RxCheckSum=CheckSum) and (RxPacketNbr=PacketNbr) then
        begin
          (* ACK : Next Paquet *)
          Send(Port,Chr(ACK)); RxPacket := TRUE; Goto FIN
        end;
      WriteLn ('Mauvais paquet !');
      Send(Port,Chr(NAK))
    end;
    (* Ne peut recevoir le paquet *)
    WriteLn ('Paquet Timeout');
    RxPacket := FALSE;
FIN: End;

Function TxStartup(Port:Integer;
               Var NCGbyte:Byte):Boolean;
Label FIN;
Var Code  : Integer;
Begin
  (* Efface tampon de r‚ception *)
  R_Flush (Port);
  (* Attend d‚but en NAK ou 'C' or 'G' *)
  Code := Byte(Receive(Port));
  (* CaractŠre re‡u *)
  if Code = NAK then NCGbyte := NAK;
  if Code = Ord('C') then NCGbyte := Ord('C');
  if Code = Ord('G') then NCGbyte := Ord('G');
  TxStartup:=True;
End;

Function RxStartup(Port:Integer;
               Var NCGbyte:Byte)
                 : Boolean;
Label FIN;
Var I     : Integer;
    Code  : Integer;
    Result: Boolean;
Begin
  (* Efface tampon de r‚ception *)
  R_Flush (Port);
  (* Envoie NAK ou 'C' *)
  WriteLn ('Lancer en DERNIER !');
  WriteLn ('Appuyer sur une touche ...');
  Repeat Until ReadKey<>#0;
  for I := 1 to 20 do { Boucle si le sender ne r‚pond pas }
    begin
      (* Arrˆt du mode CRC aprŠs 4 essais *)
      if (NCGbyte<>NAK) and (i=5) then  NCGbyte := NAK;
      (* Dit au sender : Ok to RECEIVE *)
      Send(Port,Chr(NCGbyte));
      Write (' -> Transfert en ');
      If NCGbyte=NAK then WriteLn ('Xmodem');
      If NCGbyte=Ord('C') then WriteLn ('Ymodem');
      If NCGbyte=Ord('G') then WriteLn ('Ymodem-G');
      { V‚rif. si l'envoyeur r‚pond par un paquet ! }
      Code := Byte(Receive(Port));
      { Octet re‡u que l'on remet dans le tampon }
      UnReceive (Port,Chr(Code));
      Result := TRUE; Goto FIN
    end;
  WriteLn ('Pas de r‚ponse du Sender');
  Result := FALSE;
FIN:
  RxStartup := Result;
End;

Function TxEOT(Port:Integer):Boolean;
Label FIN;
Var I    : Integer;
    Code : Integer;
Begin
  for I := 0 to 10 do
    begin
      Send(Port,Chr(EOT));
      (* Attend une r‚ponse *)
      Code := Byte(Receive(Port));
      if Code = ACK then begin TxEOT := TRUE; Goto FIN end
    end;
  TxEOT := FALSE;
FIN: End;

End.