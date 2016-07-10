        TITLE   COM_UNIT
        PAGE    60,132

; Communications Package for the IBM PC and XT
; (C) Copyright 1984 by Richard A. Gillmann
; May be copied and used freely for any non-commercial purpose.
;
; Please send all comments and queries  about this package
; to Gillmann@ISIB.ARPA or call (213) 822-2800
;
; o Supports both serial ports simultaneously
; o All speeds to 19200 baud
; o Compatible with PC, XT
; o Built in XON/XOFF flow control option
; o Assembly language calling conventions
; o Logs all comm errors
; o Direct connect or modem protocol


; 8259 ports

INTA00  EQU     20H                     ; 8259a port, a0 = 0
INTA01  EQU     21H                     ; 8259a port, a0 = 1

; flow control characters

CONTROL_Q EQU   11H                     ; XON
CONTROL_S EQU   13H                     ; XOFF

; modem protocol

DIRECT  EQU     1
MODEM   EQU     0
 
        PAGE
 
; table for each serial port
 
SP_TAB          STRUC
 
; parameters for this interrupt level
 
INT_COM         DB      ?               ; interrupt number
IRQ             DB      ?               ; 8259a ocw1 mask
NIRQ            DB      ?               ; complement of above
EOI             DB      ?               ; 8259a ocw2 specific end of interrupt
 
; interrupt handlers for this level
 
HANDLER_ADDR    DD      ?               ; current handler
 
; previous values

OLD_HANDLER	DD	?		; handler's address
OLD_SPEED	DW	?		; baud rate
OLD_PARITY	DB	?		; parity 
OLD_IER         DB      ?               ; interrupt enables
OLD_MCR         DB      ?               ; modem controls
OLD_INT1        DB      ?               ; 8259 interrupts
 
; status
 
PORT_OPEN       DB      ?               ; 0=no, 1=yes
MAKE_ECHO       DB      ?               ; 0=no, 1=yes
CONNECTION      DB      ?               ; 1=modem, 0=direct
PORT_ABSENT     DB      ?               ; 0=no, 1=yes
XON_XOFF        DB      ?               ; 1=enabled, 0=disabled

; flow control state
 
HOST_OFF        DB      ?               ; host
PC_OFF          DB      ?               ; pc XOFF'ed (1=yes,0=no)

; error counts
 
EOVFLOW         DW      ?               ; buffer overflows
EOVRUN          DW      ?               ; receive overruns
EBREAK          DW      ?               ; break chars
EFRAME          DW      ?               ; framing errors
EPARITY         DW      ?               ; parity errors
EXMIT           DW      ?               ; transmission errors
EDSR            DW      ?               ; data
ECTS            DW      ?               ; clear to send errors
 
; 8250 ports
 
DATREG          DW      ?               ; data
IER             DW      ?               ; interrupt enable register
IIR             DW      ?               ; interrupt identification register
LCR             DW      ?               ; line control register
MCR             DW      ?               ; modem control register
LSR             DW      ?               ; line status register
MSR             DW      ?               ; modem status register

; buffer variables
 
PTR_TDATA       DD      ?               ; pointer to transmit buffer
TBUFF_SIZE      DW      ?               ; size of transmit buffer
START_TDATA     DW      ?               ; index to first char in x-mit buffer
END_TDATA       DW      ?               ; index to first free in x-mit buffer
SIZE_TDATA      DW      ?               ; number of characters in x-mit buffer
 
PTR_RDATA       DD      ?               ; pointer to receive buffer
RBUFF_SIZE      DW      ?               ; size of receive buffer
START_RDATA     DW      ?               ; index to first char in rec. buffer
END_RDATA       DW      ?               ; index to first free in rec. buffer
SIZE_RDATA      DW      ?               ; number of characters in rec. buffer

SP_TAB          ENDS

        PAGE

DATA    SEGMENT PUBLIC 'DATA'

; data areas for each port

 EXTRN PTR_AREA1: DWORD                 ; pointer to COM1 or COM3 data area
 EXTRN PTR_AREA2: DWORD                 ; pointer to COM2 or COM4 data area

DATA    ENDS
 
        PAGE
 
CODE    SEGMENT PUBLIC 'CODE'
 
        ASSUME  CS:CODE,DS:DATA,ES:NOTHING
 
        PUBLIC  INT_HNDLR1,INT_HNDLR2

        PAGE
 
; internal routine
; sendi - send a character immediately (put at beginning of queue)
; AL = char to write
 
SENDII  PROC    NEAR
 
        PUSH    DX                      ; save DX
        MOV     DX,TBUFF_SIZE[SI]       ;
        CMP     SIZE_TDATA[SI],DX       ; buffer full?
        JB      LI4A                    ; jump if not
        INC     EOVFLOW[SI]             ; bump error count
        MOV     BX,START_TDATA[SI]      ; BX points to first char in buffer
        DEC     BX                      ;
        LES     DI,PTR_TDATA[SI]        ;
        MOV     BYTE PTR ES:[DI][BX],AL ; clobber first char in buffer
        JMP     SHORT LI4B              ; continue
 
LI4A:   MOV     BX,START_TDATA[SI]      ; BX points to first char in buffer
        DEC     BX                      ; backup the ptr
        CMP     BX,0                    ; before beginning?
        JNE     LI4                     ; jump if not
        MOV     BX,TBUFF_SIZE[SI]       ; point to end if so
 
LI4:    DEC     BX                      ;
        LES     DI,PTR_TDATA[SI]        ; move char to buffer
        MOV     BYTE PTR ES:[DI][BX],AL ;
        INC     BX                      ;
        MOV     START_TDATA[SI],BX      ; save new start_tdata
        INC     SIZE_TDATA[SI]          ; one more character in x-mit buffer
 
LI4B:   MOV     DX,IER[SI]              ; interrupt enable register
        IN      AL,DX                   ; get it
        TEST    AL,2                    ; see if TX interrupts are enabled
        JNZ     LI44                    ; jump if so
        MOV     AL,0FH                  ; if not then modem, rcv, tx, line error
        OUT     DX,AL                   ; are enabled
 
LI44:   POP     DX                      ; recover DX
        RET                             ; done

SENDII  ENDP
 
        PAGE
 
; internal routine
; bump error counts from line status in AL
 
 
E_BUMP  PROC    NEAR
        TEST    AL,2                    ; overrun error?
        JZ      LSI1                    ; jump
        INC     EOVRUN[SI]              ; else
 
LSI1:   TEST    AL,4                    ; parity error?
        JZ      LSI2                    ; jump
        INC     EPARITY[SI]             ; else
 
LSI2:   TEST    AL,8                    ; framing error?
        JZ      LSI3                    ; jump
        INC     EFRAME[SI]              ; else

LSI3:   TEST    AL,16                   ; break received?
        JZ      LSI4                    ; jump
        INC     EBREAK[SI]              ; else
 
LSI4:   RET                             ; done
 
E_BUMP  ENDP
 
        PAGE
 
; internal routine
; modem send protocol
 
M_PROTOCOL PROC NEAR
 
        MOV     AH,1                    ;
        MOV     AL,CONNECTION[SI]       ; modem connection?
        CMP     AL,DIRECT               ; if not, skip DSR & CTS protocol
        JE      E_PROTOCOL              ;
        XOR     AH,AH                   ;

; tell modem we're ready to send
 
        MOV     DX,MCR[SI]              ; modem control register
        MOV     AL,00001011B            ; OUT2, RTS, DTR
        OUT     DX,AL                   ; terminal ready, request to send
        NOP                             ;
        NOP                             ;
 
; see if modem says data set ready
 
        MOV     DX,MSR[SI]              ; modem status register
        IN      AL,DX                   ; get modem status
        AND     AL,20H                  ; data set ready?
        JZ      E_PROTOCOL              ; no, go back
 
; see if modem says it's clear to send
 
        IN      AL,DX                   ; get modem status
        AND     AL,10H                  ; clear to send?
        JZ      E_PROTOCOL              ; no, go back
        MOV     AH,1                    ; modem ready to receive data
 
E_PROTOCOL:
        RET                             ;
 
M_PROTOCOL ENDP
 
        PAGE
 
; internal routines for flow control
 
; flow_in - respond to flow control commands from host
; flow_out - issue flow control commands to host
 
FLOW_IN PROC    NEAR
 
        PUSH    AX                      ; save
        CMP     XON_XOFF[SI],1          ; flow control enabled?
        JNE     FI_2                    ; do nothing if disabled
        AND     AL,7FH                  ; strip parity
        CMP     AL,CONTROL_S            ; stop
        JNE     FI_1                    ; jump
        MOV     PC_OFF[SI],1            ; we must shut up
        JMP     SHORT FI_2              ; continue
 
FI_1:   CMP     AL,CONTROL_Q            ; go command received?
        JNE     FI_2                    ; no, must be normal char
        MOV     PC_OFF[SI],0            ; we start talking again
 
FI_2:   POP     AX                      ; restore char
        RET                             ; done
 
FLOW_IN ENDP
 
FLOW_OUT PROC   NEAR
 
        PUSH    AX                      ;
        CMP     XON_XOFF[SI],1          ; flow control enabled?
        JNE     FO_X                    ; do nothing if disabled
        CMP     HOST_OFF[SI],1          ; host
        JE      FO_X                    ; jump
        MOV     AX,RBUFF_SIZE           ;
        SHR     AX,1                    ; buffer size / 2
        CMP     SIZE_RDATA[SI],AX       ; receive buffer nearly full?
        JLE     FO_X                    ; done
        MOV     AL,CONTROL_S            ; turn
        CALL    SENDII                  ; send
        MOV     HOST_OFF[SI],1          ; host
 
FO_X:
        POP     AX
        RET                             ; done
 
FLOW_OUT ENDP
 
        PAGE
 
; int_hndlr1 - handles interrupts generated by COM1 and COM3
 
INT_HNDLR1 PROC  FAR
        PUSHF                           ;
        PUSH    SI                      ; save DI
        PUSH    DS                      ; save DS
        PUSH    AX                      ; save AX
        MOV     AX,DATA                 ; our data segment
        MOV     DS,AX                   ; to DS
        LDS     SI,PTR_AREA1            ; data area for COM1 and COM3
        JMP     SHORT INT_COMMON        ; continue
 
; int_hndlr2 - handles interrupts generated by COM2 and COM4
 
INT_HNDLR2 PROC  FAR
        PUSHF                           ;
        PUSH    SI                      ; save DI
        PUSH    DS                      ; save DS
        PUSH    AX                      ; save AX
        MOV     AX,DATA                 ; our data segment
        MOV     DS,AX                   ; to DS
        LDS     SI,PTR_AREA2            ; data area for COM2 and COM4

; body of interrupt handler

INT_COMMON:
        PUSH    BX                      ; save
        PUSH    CX                      ;
        PUSH    DX                      ;
        PUSH    BP                      ;
        PUSH    DI                      ;
        PUSH    ES                      ;
 
 
; clear the interrupt controller flag
 
        MOV     DX,INTA00               ; 8259
        MOV     AL,EOI[SI]              ; specific end of interrupt
        OUT     DX,AL                   ; clear flag
 
 
; find out where interrupt came from and jump to routine to handle it
 
        MOV     DX,IIR[SI]              ;
        IN      AL,DX                   ;
        CMP     AL,4                    ;
        JNE     TST_TX                  ;
        JMP     RX_INT                  ; if from the receiver

TST_TX:
        CMP     AL,2                    ;
        JE      TX_INT                  ; if from the transmitter
        CMP     AL,6                    ;
        JE      LSTAT_INT               ; interrupt because of line status
        CMP     AL,0                    ;
        JE      MSTAT_INT               ; interrupt because of modem status
        JMP     FAR PTR INT_END         ; junk, go away
                                        ; (don't fix far ptr stuff)
 
LSTAT_INT:
        MOV     DX,LSR[SI]              ; clear interrupt
        IN      AL,DX                   ;
        CALL    E_BUMP                  ; bump
        JMP     REPOLL                  ; see if any more interrupts
 
MSTAT_INT:
        MOV     DX,MSR[SI]              ; clear interrupt
        IN      AL,DX                   ;
        NOP                             ; then see if TX conditions met
        NOP                             ;
 
TX_INT:
        MOV     DX,LSR[SI]              ; line status register
        IN      AL,DX                   ;
        AND     AL,20H                  ; transmitter ready?
        JNZ     GOODTX                  ; yes
        JMP     REPOLL                  ; no, see other interrupts
 
GOODTX:
        CMP     PC_OFF[SI],1            ; have XOFFed?
        JNE     GOODTX1                 ; jump if not
        CMP     HOST_OFF[SI],1          ; has host also shut up?
        JNE     SEND_NO_MORE            ; jump
 
; clear XON/XOFF deadlock
 
        MOV     PC_OFF[SI],0            ; we speak
        MOV     HOST_OFF[SI],0          ; they reply
        MOV     AL,CONTROL_Q            ; but only when
        CALL    SENDII                  ; we let them

GOODTX1:
        CMP     SIZE_TDATA[SI],0        ; see if any more data to send
        JG      HAVE_DATA               ; if positive then there is data to send
 
; if no data to send then reset TX interrupt and return
 
SEND_NO_MORE:
        MOV     DX,IER[SI]              ;
        MOV     AL,0DH                  ; just modem, rcv and line error
        OUT     DX,AL                   ; are set
        JMP     REPOLL                  ;
 
HAVE_DATA:
        CALL    M_PROTOCOL              ; do modem protocol if necessary
        CMP     AH,1                    ;
        JNE     REPOLL                  ; modem not ready
        MOV     BX,START_TDATA[SI]      ; BX points to next char. to be sent
        DEC     BX                      ;
        MOV     DX,DATREG[SI]           ; DX equals port to send data to
        LES     DI,PTR_TDATA[SI]        ;
        MOV     AL,BYTE PTR ES:[DI][BX] ; get data from buffer
        OUT     DX,AL                   ; send data
        INC     BX                      ; increment start_tdata
        CMP     BX,TBUFF_SIZE[SI]       ; see if gone past end
        JB      NTADJ                   ; if not then skip
        MOV     BX,0                    ; reset to beginning
 
NTADJ:  INC     BX
        MOV     START_TDATA[SI],BX      ; save start_tdata
        DEC     SIZE_TDATA[SI]          ; one less character in x-mit buffer
        MOV     AL,CONNECTION[SI]       ; modem connection?
        CMP     AL,DIRECT               ; if not, skip RTS protocol
        JE      E_SEND                  ;
        MOV     DX,MCR[SI]              ; modem control register
        MOV     AL,00001001B            ; OUT2, DTR
        OUT     DX,AL                   ; terminal not ready to send
        NOP                             ;
        NOP                             ;
 
E_SEND:
        JMP     REPOLL                  ;

RX_INT:
        MOV     DX,LSR[SI]              ; check and see if read is real
        IN      AL,DX                   ;
        AND     AL,1                    ; look
        JNZ     GOOD_RX                 ; real, go get byte
        JMP     REPOLL                  ; go look for other interrupts
 
GOOD_RX:
        MOV     DX,DATREG[SI]           ; 8250 data register
        IN      AL,DX                   ; get data
;       CALL    FLOW_IN                 ; respond to f.c. commands from host
        MOV     BX,RBUFF_SIZE[SI]       ;
        CMP     SIZE_RDATA[SI],BX       ; see if any room
        JL      GOOD_RX1                ; continue if so
        INC     EOVFLOW[SI]             ; bump overflow error count
        JMP     SHORT REPOLL            ; punt
 
GOOD_RX1:
        MOV     BX,END_RDATA[SI]        ; BX points to free space
        DEC     BX                      ;
        LES     DI,PTR_RDATA[SI]        ; move data to buffer
        MOV     BYTE PTR ES:[DI][BX],AL ;
        INC     SIZE_RDATA[SI]          ; got one more character
        INC     BX                      ; increment end_rdata pointer
        CMP     BX,RBUFF_SIZE[SI]       ; see if gone past end
        JB      NRADJ                   ; if not then skip
        MOV     BX,0                    ; else adjust to beginning
 
NRADJ:  INC     BX
        MOV     END_RDATA[SI],BX        ; save value
;       CALL    FLOW_OUT                ; issue flow control commands to host
 
REPOLL:
        MOV     DX,LSR[SI]              ; we always expect receive data, so
        IN      AL,DX                   ; check status to see if any is ready.
        AND     AL,1                    ; get received data bit
        JNZ     GOOD_RX                 ; yes,
        MOV     DX,IER[SI]              ; else look
        IN      AL,DX                   ; to see if we are enabled to send data
        TEST    AL,2                    ; TX bit set?
        JZ      INT_END                 ; not enabled, so go away
        MOV     DX,LSR[SI]              ; we are enabled,
        IN      AL,DX                   ; so look for TX condition
        AND     AL,20H                  ;
        JZ      INT_END                 ; no data to transmit
        JMP     GOODTX                  ; go get more data
 
INT_END:
        POP     ES                      ; no more to do
        POP     DI                      ; restore regs
        POP     BP                      ;
        POP     DX                      ;
        POP     CX                      ;
        POP     BX                      ;
        POP     AX                      ;
        POP     DS                      ;
        POP     SI                      ;
        POPF                            ;
        IRET                            ; see you later!
 
INT_HNDLR2 ENDP
 
INT_HNDLR1 ENDP
 
CODE    ENDS
 
        END
