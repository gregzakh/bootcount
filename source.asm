bits 64

default rel

global getboot
global main

extern printf                            ; legacy_stdio_definitions.lib
extern __imp_RegOpenKeyExA               ; all other below - advapi32.lib
extern __imp_RegQueryValueExA
extern __imp_RegCloseKey

section .data noexec
dir: db "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management\\PrefetchParameters", 0
val: db "BootId", 0
err: db "[!] Perhaps required data is missed or the system does not contains it.", 0xA, 0
pm1: db "Total system boot tries  : %lu", 0xA, 0
pm2: db "Number of boot completed : %lu", 0xA, 0
pm3: db "Total failed boot count  : %lu", 0xA, 0
pm4: db "Failure percentage       : %lu%%", 0xA, 0

section .text exec
getboot:
    mov   qword [rsp +  8h], rcx
    sub   rsp, 48h
    mov   qword [rsp + 38h], 0           ; key (HKEY)
    mov   dword [rsp + 30h], 4           ; sz (sizeof(DWORD))
    lea   rax,  [rsp + 38h]              ; &key
    mov   qword [rsp + 20h], rax
    mov   r9d, 1                         ; samDesired = KEY_QUERY_VALUE
    xor   r8d, r8d                       ; ulOptions = 0
    lea   rdx, [rel dir]                 ; lpSubKey
    mov   rcx, -2147483646               ; hKey (HKEY_LOCAL_MACHINE)
    call  near [rel __imp_RegOpenKeyExA]
    test  eax, eax                       ; ERROR_SUCCESS (or not)
    jnz   denied
    lea   rax,  [rsp + 30h]              ; &sz
    mov   qword [rsp + 28h], rax
    mov   rax, qword [rsp + 50h]
    mov   qword [rsp + 20h], rax
    xor   r9d, r9d                       ; lpType = NULL
    xor   r8d, r8d                       ; lpReserved = NULL
    lea   rdx,  [rel val]                ; lpValueName
    mov   rcx, qword [rsp + 38h]         ; key
    call  near  [rel __imp_RegQueryValueExA]
    mov   rcx, qword [rsp + 38h]         ; now key should be freed
    call  near [rel __imp_RegCloseKey]
  denied:
    add   rsp, 48h                       ; release stack
    ret
main:
    sub   rsp, 0x38
    mov   eax, dword [abs 7FFE02C4h]     ; tried (KUSER_SHARED_DATA->BootId)
    mov   dword [rsp + 24h], eax
    mov   dword [rsp + 20h], 0           ; bdone (data from registry)
    lea   rcx,  [rsp + 20h]
    call  getboot
    cmp   dword [rsp + 20h], 0           ; warn if data is still null
    jnz   success
    lea   rcx,  [rel err]
    call  printf
  success:
    mov   edx, dword [rsp + 24h]
    lea   rcx, [rel pm1]
    call  printf                         ; show tried value
    mov   edx, dword [rsp + 20h]
    lea   rcx, [rel pm2]
    call  printf                         ; show bdone value
    mov   eax, dword [rsp + 20h]
    mov   ecx, dword [rsp + 24h]
    sub   ecx, eax
    mov   eax, ecx
    mov   edx, eax
    lea   rcx, [rel pm3]
    call  printf                         ; show delta of tried and bdone
    mov   eax, dword [rsp + 20h]
    mov   ecx, dword [rsp + 24h]
    sub   ecx, eax
    mov   eax, ecx
    imul  eax, eax, 64h
    xor   edx, edx
    div   dword [rsp + 24h]
    mov   edx, eax
    lea   rcx, [rel pm4]
    call  printf                         ; show failure percentage
    xor   eax, eax
    add   rsp, 0x38                      ; release stack
    ret
