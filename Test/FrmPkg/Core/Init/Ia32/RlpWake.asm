;------------------------------------------------------------------------------
;
; Copyright (c) 2016, Intel Corporation. All rights reserved.<BR>
; This program and the accompanying materials
; are licensed and made available under the terms and conditions of the BSD License
; which accompanies this distribution.  The full text of the license may be found at
; http://opensource.org/licenses/bsd-license.php.
;
; THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
; WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
;
; Module Name:
; 
;    RlpWake.asm
;
; Abstract:
;
;------------------------------------------------------------------------------

include Smx.inc

.686P
.MODEL FLAT, C
.CODE

EXTERNDEF PostInitAddrRlp:DWORD

;------------------------------------------------------------------------------
; VOID 
; AsmRlpWakeUpCode (
;     VOID    
;     )
;------------------------------------------------------------------------------
AsmRlpWakeUpCode PROC PUBLIC
  cli

  ;
  ; Enable SMI
  ;
  mov   ebx, 0
  mov   eax, GET_SEC_SMCTRL
  DB 0fh, 37h ; GETSEC

  ; Check DLE
  mov     eax, TXT_PUBLIC_SPACE
  add     eax, TXT_HEAP_BASE                       ; eax = HEAP Base Ptr
  mov     esi, [eax]                               ; esi = HEAP Base
  mov     edx, [esi]                               ; edx = BiosOsDataSize
  add     esi, edx                                 ; esi = OsMleDataSize Offset
  add     esi, 8                                   ; esi = MlePrivateData Offset

  mov     edi, esi                                        ; edi = MyOsMleData Offset
  add     edi, _TXT_OS_TO_MLE_DATA._MlePrivateDataAddress ; edi = MlePrivateDataAddress offset
  mov     esi, [edi]                                      ; esi = TxtOsMleData Offset

  mov     edi, esi                                 ; edi = MlePrivateData Offset
  add     edi, _MLE_PRIVATE_DATA._ApEntry          ; edi = ApEntry Offset

  mov     eax, [edi]
  cmp     eax, 0
  jz      NonDleAp


    mov     eax, TXT_PUBLIC_SPACE
    add     eax, TXT_HEAP_BASE                       ; eax = HEAP Base Ptr
    mov     esi, [eax]                               ; esi = HEAP Base
    mov     edx, [esi]                               ; edx = BiosOsDataSize
    add     esi, edx                                 ; esi = OsMleDataSize Offset
    add     esi, 8                                   ; esi = MlePrivateData Offset

    mov     edi, esi                                        ; edi = MyOsMleData Offset
    add     edi, _TXT_OS_TO_MLE_DATA._MlePrivateDataAddress ; edi = MlePrivateDataAddress offset
    mov     esi, [edi]                                      ; esi = TxtOsMleData Offset

    mov     edi, esi                                 ; edi = MlePrivateData Offset
    add     edi, _MLE_PRIVATE_DATA._IdtrReg          ; edi = IDTR offset
    lidt    fword ptr [edi]                          ; Reload IDT
    mov     edi, esi                                 ; edi = MlePrivateData Offset
    add     edi, _MLE_PRIVATE_DATA._GdtrReg          ; edi = GDTR offset
    lgdt    fword ptr [edi]                          ; Reload GDT

    mov     eax, (_MLE_PRIVATE_DATA PTR [esi])._RlpDsSeg ; eax = data segment
    mov     ds, ax
    mov     ss, ax
    mov     es, ax
    mov     fs, ax
    mov     gs, ax

    mov     eax, (_MLE_PRIVATE_DATA PTR [esi])._TempEspRlp ; eax = temporary stack
    sub     eax, 20h

    ; patch Offset/Segment

    sub     eax, 4
    mov     edx, (_MLE_PRIVATE_DATA PTR [esi])._RlpPostSinitSegment ; edx = RlpPostSinitSegment
    mov     [eax], edx

    sub     eax, 4
    mov     edx, (_MLE_PRIVATE_DATA PTR [esi])._RlpPostSinitOffset  ; edx = RlpPostSinitOffset
    mov     [eax], edx

    mov     esp, eax

    ; reload CS
    retf

POST_INIT_ADDR_RLP  = $ - offset AsmRlpWakeUpCode

  ;
  ; Notify RLP wakeup
  ;
; Critical Section - start -----------------------

  mov     eax, TXT_PUBLIC_SPACE
  add     eax, TXT_HEAP_BASE                       ; eax = HEAP Base Ptr
  mov     esi, [eax]                               ; esi = HEAP Base
  mov     edx, [esi]                               ; edx = BiosOsDataSize
  add     esi, edx                                 ; esi = OsMleDataSize Offset
  add     esi, 8                                   ; esi = MlePrivateData Offset

  mov     edi, esi                                        ; edi = MyOsMleData Offset
  add     edi, _TXT_OS_TO_MLE_DATA._MlePrivateDataAddress ; edi = MlePrivateDataAddress offset
  mov     esi, [edi]                                      ; esi = TxtOsMleData Offset

  mov     edi, esi                                 ; edi = MlePrivateData Offset
  add     edi, _MLE_PRIVATE_DATA._Lock             ; edi = Lock Offset
  mov     ebp, edi                                 ; ebp = Lock Offset

; AcquireLock:    
  mov         al, 1
TryGetLock:
  xchg        al, byte ptr [ebp]
  cmp         al, 0
  jz          LockObtained
;  pause
  jmp         TryGetLock       
LockObtained:

  mov     edi, esi                                       ; edi = MlePrivateData Offset
  add     edi, _MLE_PRIVATE_DATA._RlpInitializedNumber   ; edi = RlpInitializedNumber Offset
  inc     DWORD PTR [edi]                                ; increase RlpInitializedNumber

; ReleaseLock:    
  mov         al, 0
  xchg        al, byte ptr [ebp]

; Critical Section - end -----------------------

  mov     eax, TXT_PUBLIC_SPACE
  add     eax, TXT_HEAP_BASE                       ; eax = HEAP Base Ptr
  mov     esi, [eax]                               ; esi = HEAP Base
  mov     edx, [esi]                               ; edx = BiosOsDataSize
  add     esi, edx                                 ; esi = OsMleDataSize Offset
  add     esi, 8                                   ; esi = MlePrivateData Offset

  mov     edi, esi                                        ; edi = MyOsMleData Offset
  add     edi, _TXT_OS_TO_MLE_DATA._MlePrivateDataAddress ; edi = MlePrivateDataAddress offset
  mov     esi, [edi]                                      ; esi = TxtOsMleData Offset

  mov     edi, esi                                 ; edi = MlePrivateData Offset
  add     edi, _MLE_PRIVATE_DATA._ApEntry          ; edi = ApEntry Offset

  mov     eax, [edi]
  jmp     eax
NonDleAp:

  ; Should not get here
  jmp $
AsmRlpWakeUpCode ENDP

PostInitAddrRlp LABEL DWORD
  DD POST_INIT_ADDR_RLP

END
