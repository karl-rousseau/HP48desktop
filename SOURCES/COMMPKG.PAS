{$R-,S+,I-,F+,O+,A+,V-,B-,N-,E-,D+,L- }
Unit CommPkg;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ   Communication Package for the IBM PC, XT and AT (and true compatibles)    บ
บ                       ฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤ                      บ
บ      (C) Copyright 1984 by Richard Gillmann (Assembler version).            บ
บ      (C) Copyright 1987 by JP. Parisy (TURBO Pascal version).               บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ  Permission to copy and distribute, but not for profit, is hereby granted,  บ
บ  provided that this note is included.                                       บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ  + Supports both serial ports simultaneously                                บ
บ  + All speeds from 75 to 19200 bauds                                        บ
บ  + Records all communication errors                                         บ
บ  + Direct connection or modem protocol (partially done)                     บ
บ  + Optionally logs all received characters                                  บ
วฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤฤถ
บ  Take care! These procedures uses interrupt vectors which must be restored  บ
บ  before leaving the main program.                                           บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}

Interface

Uses Dos,Crt;

Procedure  Open_Com (PortNumber       : Byte;
                     BaudRate         : Integer;
                     Parity           : Char;
                     TXSize           : Word;
                     RXSize           : Word);
Procedure  Close_Com(PortNumber: Byte);
Procedure  Set_connection(PortNumber: Byte; ConnectionType: Byte);
Procedure  R_Flush(PortNumber: Byte);
Procedure  X_Flush(PortNumber: Byte);
Procedure  UnReceive(PortNumber: Byte; CharToPush: Char);
Procedure  Send(PortNumber: Byte; CharToSend: Char);
Procedure  SendString(PortNumber: Byte; StringToSend: String);
Procedure  Sendi(PortNumber: Byte; CharToSend: Char);
Procedure  Send_local(PortNumber: Byte; CharToSend: Char);
Procedure  Send_Break(PortNumber: Byte);
Procedure  X_Synchro(PortNumber: Byte);

Function   Port_open(PortNumber: Byte): Boolean;
Function   R_Count(PortNumber: Byte): Word;
Function   X_Free(PortNumber: Byte): Word;
Function   X_Count(PortNumber: Byte): Word;
Function   Receive(PortNumber: Byte): Char;
Function   ReceiveString(PortNumber: Byte): String;
Function   PortReady(PortNumber: Byte): Boolean;

Const
   ON  = TRUE;
   OFF = FALSE;
   MODEM = 0;
   DIRECT = 1;

{ Interrupt numbers                                                           }
   IntCom1=$0C;                      { COM1 and COM3 from 8259                }
   IntCom2=$0B;                      { COM2 and COM4 from 8259                }

{ 8259 ports                                                                  }
   Inta00=$20;                       { 8259A Port, A0 = 0                     }
   Inta01=$21;                       { 8259A Port, A0 = 1                     }

{ COM1 and COM3 level 4                                                       }
   Irq4=$10;                         { 8259A OCW1 mask, M4=1, A0=0            }
   Nirq4=$EF;                        { complement of above                    }
   Eoi4=$64;                         { 8259A OCW2 specific IRQ4 EOI, A0=0     }

{ COM2 and COM4 level 3                                                       }
   Irq3=$08;                         { 8259A OCW1 mask, M3=1, A0=0            }
   Nirq3=$F7;                        { complement of above                    }
   Eoi3=$63;                         { 8259A OCW2 specific IRQ3 EOI, A0=0     }

{ Divisor for 1 baud                                                          }
   Divisor_1_baud=115200;

{ Maximum number of ports                                                     }
   MaxPort=4;

Type

{ Buffers definition                                                          }
   Buffer= Record
             Data : Array[1..60000] of Char;
           End;
   Buffer_pointer= ^Buffer;

{                                                                             }
{ Table for each serial port                                                  }
{                                                                             }
   Sp_Tab= Record
                             { Parameters for this interrupt level            }
             IntCom : Byte;          { interrupt number                       }
             Irq    : Byte;          { 8259a ocw1 mask                        }
             Nirq   : Byte;          { complement of above                    }
             Eoi    : Byte;          { 8259a ocw2 specific end of interrupt   }

                             { Interrupt handlers for this level              }
             HandlerAddr: Pointer;   { current handler                        }

                             { Previous Values                                }
             OldHandler : Pointer;   { handler's address                      }
             OldSpeed   : Integer;   { baud rate                              }
             OldLcr     : Byte;      { parity and bits number                 }
             OldIer     : Byte;      { interrupt enables                      }
             OldMcr     : Byte;      { modem controls                         }
             OldInt1    : Byte;      { 8259 interrupts                        }

                             { Status                                         }
             PortOpen   : Boolean;
             MakeEcho   : Boolean;
             Connection : Byte;      { Modem, Direct                          }
             PortAbsent : Boolean;
             XonXoff    : Boolean;   { Enabled, Disabled                      }

                             { Flow control state                             }
             HostOff    : Boolean;
             PcOff      : Boolean;

                             { Error counts                                   }
             Eovflow    : Word;      { buffer overflows                       }
             Eovrun     : Word;      { receive overruns                       }
             Ebreak     : Word;      { break chars                            }
             Eframe     : Word;      { framing errors                         }
             Eparity    : Word;      { parity errors                          }
             Exmit      : Word;      { transmission errors                    }
             Edsr       : Word;      { data set ready errors                  }
             Ects       : Word;      { clear to send errors                   }

                             { 8250 port offsets                              }
             Datreg     : Word;      { data register                          }
             Ier        : Word;      { interrupt enable register              }
             Iir        : Word;      { interrupt identification register      }
             Lcr        : Word;      { line control register                  }
             Mcr        : Word;      { modem control register                 }
             Lsr        : Word;      { line status register                   }
             Msr        : Word;      { modem status register                  }

                             { Buffer Variables                               }
             Xbuf       : Buffer_pointer; { transmit buffer                   }
             XSize      : Word;      { size of transmit buffer                }
             StartXData : Word;      { index to first character               }
             EndXData   : Word;      { index to first free space              }
             SizeXData  : Word;      { number of characters in buffer         }

             Rbuf       : Buffer_pointer; { receive buffer                    }
             RSize      : Word;      { size of receive buffer                 }
             StartRData : Word;      { index to first character               }
             EndRData   : Word;      { index to first free space              }
             SizeRData  : Word;      { number of characters in buffer         }
           End;

Var CurrentArea : Array[1..MaxPort] of Sp_Tab;
    Ptr_area1, Ptr_area2 : Pointer;

Implementation

Var Num_int, Num_err : Integer;
    Work_Char        : Char;
    Count            : Word;
    Num_port         : Byte;
    ExitSave         : Pointer;

    RS232_Base       : Array[1..4] of Word ABSOLUTE $0040:0000;

{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                           Interrupts management                             บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
{$L COM_UNIT.OBJ}
Procedure Int_Hndlr1; External;
Procedure Int_Hndlr2; External;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                             Turn Interrupts ON                              บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure IntOn;
InLine($FB);
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                             Turn Interrupts OFF                             บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure IntOff;
InLine($FA);
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                     Open a given communication port                         บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Open_Com (PortNumber       : Byte;
                     BaudRate         : Integer; { 19200 max }
                     Parity           : Char;
                     TXSize           : Word;
                     RXSize           : Word);
Var Work_Byte: Byte;

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If PortOpen or PortAbsent then Exit;

      IntOff;

{ Set interface address for interrupt subprograms                             }
      Case PortNumber of
         1: Ptr_area1:=Addr(CurrentArea[1]);
         2: Ptr_area2:=Addr(CurrentArea[2]);
         3: Ptr_area1:=Addr(CurrentArea[3]);
         4: Ptr_area2:=Addr(CurrentArea[4]);
      End;

{ Reset error counts                                                          }
      Eovflow:=0;
      Eovrun:=0;
      Ebreak:=0;
      Eframe:=0;
      Eparity:=0;
      Exmit:=0;
      Edsr:=0;
      Ects:=0;

{ Allocate memory, set buffer counts and indexes                              }
      If TXSize > 1024 then XSize:=TXSize;
      GetMem(Xbuf,XSize);
      StartXData:=1;
      EndXData:=1;
      SizeXData:=0;
      If RXSize > 1024 then RSize:=RXSize;
      GetMem(Rbuf,RSize);
      StartRData:=1;
      EndRData:=1;
      SizeRData:=0;

{ Reset the 8250                                                              }
      Work_Byte:=Port[Datreg]; { reset receive data condition }
      Work_Byte:=Port[Lsr];    { reset line status condition }
      Work_Byte:=Port[Msr];    { reset modem deltas and conditions }
      Work_Byte:=Port[Iir];    { reset Interrupt register }

{ Install communication interrupt vector and get previous values              }
      GetIntVec(IntCom,OldHandler);
      OldInt1:=Port[Inta01];
      OldLcr:=Port[Lcr];
      OldIer:=Port[Ier];
      OldMcr:=Port[Mcr];
      SetIntVec(IntCom,HandlerAddr);
      Port[Lcr]:=$80;
      OldSpeed:=Divisor_1_baud div Portw[Datreg];

{ Set baud rate, parity, word length and stop bits                            }
      Portw[DatReg]:=Divisor_1_baud div BaudRate;
      Work_Byte:=$1A;          { default parity is Even }
      Case Parity of
         'O': Work_Byte:=$0A;  { O(dd)   parity }
         'N': Work_Byte:=$03;  { N(one)  parity, }
      End;                     { for other settings (parity, stop bits, etc.) }
                               { see the technical sheet of the 8250 chip }
      Port[Lcr]:=Work_Byte;
      PortOpen:=TRUE;
      Port[Inta00]:=Eoi;
      IntOn;

{ Enable interrupts on 8259 and 8250                                          }
      Port[Ier]:=$0D;                       { modem, receive and line error }
      If Connection = DIRECT then
         Port[Mcr]:=$0B                     { OUT2, RTS and DTR }
      Else
         Port[Mcr]:=$09;                    { OUT2 and DTR }
      Port[Inta01]:=Port[Inta01] and Nirq;  { set enable bit }
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                        Close a communication port                           บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Close_Com(PortNumber: Byte);

Var Work_Byte: Byte;

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If not PortOpen then Exit;

{ Turn off interrupts from the communication port                             }
      IntOff;
      Port[Lcr]:=$80;
      PortW[Datreg]:=Divisor_1_baud div OldSpeed;
      Port[Lcr]:=OldLcr;
      Port[IntA01]:=OldInt1;
      SetIntVec(IntCom,OldHandler);
      IntOn;
      Port[Ier]:=OldIer;
      Port[Mcr]:=OldMcr;
      PortOpen:=FALSE;
      Work_Byte:=Port[Datreg]; { reset receive data condition }

{ Release memory buffers                                                      }
      FreeMem(Rbuf,RSize);
      FreeMem(Xbuf,XSize);
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                         Verify port installation                            บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   Port_open(PortNumber: Byte): Boolean;

Begin
   If PortNumber in [1..MaxPort] then
      Port_open:=CurrentArea[PortNumber].PortOpen
   Else Port_open:=FALSE;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                        Turn Modem Protocol ON or OFF                        บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Set_connection(PortNumber: Byte; ConnectionType: Byte);

Begin
   If PortNumber in [1..MaxPort] then
      CurrentArea[PortNumber].Connection:=ConnectionType;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                 Return the number of bytes in the input buffer              บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   R_Count(PortNumber: Byte): Word;

Begin
   R_count:=0;
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      If PortOpen then R_Count:=SizeRData;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ       Return the amount of free space remaining in the transmit buffer      บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   X_Free(PortNumber: Byte): Word;

Begin
   X_Free:=0;
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      If PortOpen then X_Free:=XSize - SizeXData;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ       Return the number of characters remaining in the transmit buffer      บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   X_Count(PortNumber: Byte): Word;

Begin
   X_Count:=0;
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      If PortOpen then X_Count:=SizeXData;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                         Clear the transmit buffer                           บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  X_Flush(PortNumber: Byte);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If PortOpen then Begin
         IntOff;
         StartXData:=1;
         EndXData:=1;
         SizeXData:=0;
         IntOn;
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                          Clear the input buffer                             บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  R_Flush(PortNumber: Byte);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If PortOpen then Begin
         IntOff;
         StartRData:=1;
         EndRData:=1;
         SizeRData:=0;
         IntOn;
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                            Send a character                                 บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Send(PortNumber: Byte; CharToSend: Char);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Xbuf^ do Begin
      If not PortOpen then Exit;
      If SizeXData >= XSize then Inc(Eovflow)
      Else Begin
         Data[EndXData]:=CharToSend;
         If EndXData >= XSize then EndXData:=1
         Else Inc(EndXData);
         IntOff;
         Inc(SizeXData);
         IntOn;

{ See if tx interrupts are enabled, if not rcv, tx, line error are enabled    }
         If (Port[Ier] and $02) = 0 then Port[Ier]:=$0F;
         If Connection = MODEM then Delay (25);
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                         Send a character string                             บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  SendString(PortNumber: Byte; StringToSend: String);
 
Var
   i,j: Integer;
 
Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Xbuf^ do Begin
      If not PortOpen then Exit;
      i:=Length(StringToSend);
      If SizeXData + i >= XSize then
         Inc(Eovflow)
      Else If i > 0 then Begin
         If Connection = MODEM then Begin
            For j:=1 to i do Begin
               Send(PortNumber, StringToSend[j]);
            End;
         End
         Else Begin
            If EndXData + i > XSize + 1 then Begin
               j:=XSize + 1 - EndXData;
               Move(StringToSend[1], Data[EndXData], j);
               Move(StringToSend[j + 1], Data[1], i - j);
               EndXData:=i - j + 1;
            End
            Else Begin
               Move(StringToSend[1], Data[EndXData], i);
               Inc(EndXData, i);
               If EndXData > XSize then EndXData:=1;
            End;
            IntOff;
            Inc(SizeXData, i);
            IntOn;

{ See if tx interrupts are enabled, if not rcv, tx, line error are enabled    }
            If (Port[Ier] and $02) = 0 then Port[Ier]:=$0F;
         End;
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ         Send a character immediately (put at beginning of queue)            บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Sendi(PortNumber: Byte; CharToSend: Char);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Xbuf^ do Begin
      If not PortOpen then Exit;
      IntOff;
      If SizeXData >= XSize then Inc(Eovflow)
      Else Inc(SizeXData);
      If StartXData <= 1 then StartXData:=XSize
      Else Dec(StartXData);
      Data[StartXData]:=CharToSend;
      IntOn;

{ See if tx interrupts are enabled, if not rcv, tx, line error are enabled    }
      If (Port[Ier] and $02) = 0 then Port[Ier]:=$0F;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ         Return the first character in the input buffer and remove it        บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   Receive(PortNumber: Byte): Char;

Var
   Work_char : Char;
   IOError   : Word;
   Ok        : Boolean; { Ajout d'un petit patch }

   Procedure Clear_Key; { Vide buffer Clavier }
   Var KbHead : Word ABSOLUTE $40:$1A;
       KbTail : Word ABSOLUTE $40:$1C;
   Begin
     ASM CLI END;
     KbHead := $1E;
     KbTail := $1E;
     ASM STI END;
   End;

Begin
   Receive:=#0;
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Rbuf^ do Begin
      If not PortOpen then Exit;
   Ok:=False;
   repeat
      If SizeRData > 0 then
        Begin
         Ok:=True;
         Work_char:=Data[StartRData];
         Receive:=Work_char;
         If StartRData < RSize then Inc(StartRData)
         Else StartRData:=1;
         IntOff;
         Dec(SizeRData);
         IntOn;
        End;
      If Keypressed then begin Ok:=True; Clear_Key; end;
   until Ok;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ               Return the input buffer as a character string                 บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   ReceiveString(PortNumber: Byte): String;

Var
   WorkString: String;
   i,j: Integer;

Begin
   ReceiveString:='';
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Rbuf^ do Begin
      If not PortOpen then Exit;
      If SizeRData > 0 then Begin
         i:=SizeRData;
         If i > 255 then i:=255;
         WorkString[0]:=Chr(i);
         If StartRData + i > RSize + 1 then Begin
            j:=RSize + 1 - StartRData;
            Move(Data[StartRData], WorkString[1], j);
            Move(Data[1], WorkString[j + 1], i - j);
            StartRData:=i - j + 1;
         End
         Else Begin
            Move(Data[StartRData], WorkString[1], i);
            Inc(StartRData, i);
            If StartRData > RSize then StartRData:=1;
         End;
         ReceiveString:=WorkString;
         IntOff;
         Dec(SizeRData, i);
         IntOn;
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ      Push a character in the input buffer (put at beginning of queue)       บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  UnReceive(PortNumber: Byte; CharToPush: Char);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Rbuf^ do Begin
      If not PortOpen then Exit;
      IntOff;
      If SizeRData >= RSize then Inc(Eovflow)
      Else Inc(SizeRData);
      If StartRData <= 1 then StartRData:=XSize
      Else Dec(StartRData);
      Data[StartRData]:=CharToPush;
      IntOn;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ       Write a character to the input buffer (at the end of the queue)       บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Send_local(PortNumber: Byte; CharToSend: Char);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do
      With Rbuf^ do Begin
      If not PortOpen then Exit;
      IntOff;
      If SizeRData >= RSize then Inc(Eovflow)
      Else Begin
         Data[EndRData]:=CharToSend;
         Inc(SizeRData);
         If EndRData >= RSize then EndRData:=1
         Else Inc(EndRData);
      End;
      IntOn;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                 Causes a break to be sent out on the line                   บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  Send_Break(PortNumber: Byte);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If not PortOpen then Exit;
      Port[Lcr]:=Port[Lcr] or $40;            { turn on Break bit }
      Delay(250);                             { wait approximately 1/4 sec. }
      Port[Lcr]:=Port[Lcr] and $BF;           { turn off Break bit }
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                   Waits until transmit buffer is empty                      บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure  X_Synchro(PortNumber: Byte);

Begin
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If not PortOpen then Exit;
      While SizeXData > 0 do Begin

{ Set DTR ON                                                                  }
         Port[Mcr]:=Port[Mcr] or $01;

{ See if tx interrupts are enabled, if not rcv, tx, line error are enabled    }
         If (Port[Ier] and $02) = 0 then Port[Ier]:=$0F;
      End;
   End;
End;
{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                Replies TRUE if there are characters to receive              บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Function   PortReady(PortNumber: Byte): Boolean;

Begin
   PortReady:=FALSE;
   If PortNumber in [1..MaxPort] then With CurrentArea[PortNumber] do Begin
      If not PortOpen then Exit;
      If SizeRData > 0 then PortReady:=TRUE;
   End;
End;

{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                             Exit Procedure                                  บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}
Procedure CommExit;

Begin
   For Num_port:=1 to MaxPort do
      Close_com(Num_port);
   ExitProc:=ExitSave;
End;

{
ษอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออป
บ                                                                             บ
บ                             Init Procedure                                  บ
บ                                                                             บ
ศอออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออออผ
}

Begin

   ExitSave:=ExitProc;
   ExitProc:=@CommExit;

{ COM3 and COM4 adresses forced in BIOS area                                  }
   If RS232_Base[3] = 0 then RS232_Base[3]:=$3E8;
   If RS232_Base[4] = 0 then RS232_Base[4]:=$2E8;

{ Initialize parameters for each serial port                                  }
   For Num_port:=1 to MaxPort do Begin
      With CurrentArea[Num_port] do Begin
         If Num_port in [1, 3] then Begin
            IntCom:=IntCom1;
            Irq:=Irq4;
            Nirq:=Nirq4;
            Eoi:=Eoi4;
            HandlerAddr:=Addr(Int_Hndlr1);
         End
         Else Begin
            IntCom:=IntCom2;
            Irq:=Irq3;
            Nirq:=Nirq3;
            Eoi:=Eoi3;
            HandlerAddr:=Addr(Int_Hndlr2);
         End;
         PortOpen:=FALSE;
         Connection:=DIRECT;
         XonXoff:=FALSE;
         HostOff:=FALSE;
         PcOff:=FALSE;
         Xbuf:=NIL;
         Rbuf:=NIL;
         RSize:=2048;
         XSize:=2048;

{ Initialize port adresses                                                    }
         DatReg:=RS232_Base[Num_Port];
         Ier:=Datreg + 1;
         Iir:=Datreg + 2;
         Lcr:=Datreg + 3;
         Mcr:=Datreg + 4;
         Lsr:=Datreg + 5;
         Msr:=Datreg + 6;
         If Datreg = 0 then
            PortAbsent:=TRUE
         Else
            PortAbsent:=FALSE;
      End;
   End;
End.
