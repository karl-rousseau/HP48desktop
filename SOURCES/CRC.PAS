(********************)
(*                  *)
(*  Calculs du CRC  *)
(*                  *)
(********************)

Unit CRC;

Interface

Function  UpdateCRC(crc:Word;data:Byte):Word;
Function  CalcTable(data,genpoly,accum:Word):Word;
Procedure InitCRC;

Implementation

Var CRCtable : array[0..255] of Word;

(* MAJ du CRC *)

Function  UpdateCRC(crc:Word;data:Byte):Word;
begin
  UpDateCRC := (crc SHL 8) XOR ( CRCtable[ (crc SHR 8) XOR data] );
end;

(* calculate CRC table entry *)

Function CalcTable(data,genpoly,accum:Word):Word;
var i : Word;
begin
  data := data SHL 8;
  for i := 8 downto 1 do
     begin
       if ( (data XOR accum) AND $8000 <> 0 )
          then accum := (accum SHL 1) XOR genpoly
          else accum := accum SHL 1;
       data := data SHL 1;
     end;
  CalcTable := accum;
end;

(* Init de la table CRC *)

Procedure InitCRC;
var i : Integer;
begin
  for i := 0 to 255 do CRCtable[i] := CalcTable(i,$1021,0);
end;

End.