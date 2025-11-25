OUTPUT_ARCH(riscv)

ENTRY(_start)


SECTIONS
{
  . = 0x80000000; /* boot loader lives in boot ROM after the device tree */
  PROVIDE( reset_vector = . );

  . = ALIGN(0x1000);

  .text :
  {
    PROVIDE( _entry = . );
    *(.reset)

	. = ALIGN(4096);
	PROVIDE( _sy_mon_enter_osbi = . );
	*(._mon_enter_osbi)

  . = ALIGN(4096);
	PROVIDE( _sy_mon_jmp_osbi = . );
	*(._mon_jmp_osbi)

	. = ALIGN(4096);
	PROVIDE( _sy_mon_enter_su = . );
	*(._mon_enter_su)
	. = ALIGN(4096);
  /*  *(*) */

  *(.text)
  . = ALIGN(8);

	PROVIDE( _txt_end = . );
  } 
  . = ALIGN(0x1000); /* Need this to create proper sections */
  
  . = 0x8003F000;
  .ipct : {
		PROVIDE(_ipct_start = .);
		*(monitor_last_page*)
		PROVIDE(_ipct_end = .);
	}
  . = ALIGN(0x1000);

  . = 0x80100000;
  PROVIDE(_fw_data_start = .);

 .rodata :
 {
  PROVIDE(_rodata_start = .);
  *(.rodata .rodata.*)
  . = ALIGN(8);
  PROVIDE(_rodata_end = .);
 } 

 . = ALIGN(0x1000);

 .data :
 {
  PROVIDE(_data_start = .);

  *(.sdata)
  *(.sdata.*)
  *(.data)
  *(.data.*)
  *(.readmostly.data)
  *(*.data)
  . = ALIGN(8);

  PROVIDE(_data_end = .);
 } 

 .dynsym : {
  PROVIDE(__dyn_sym_start = .);
  *(.dynsym)
  PROVIDE(__dyn_sym_end = .);
 } 

 .rela.dyn : {
  PROVIDE(__rel_dyn_start = .);
  *(.rela*)
  . = ALIGN(8);
  PROVIDE(__rel_dyn_end = .);
 } 

 . = ALIGN(0x1000);

 .bss :
 {
  PROVIDE(_bss_start = .);
  *(.sbss)
  *(.sbss.*)
  *(.bss)
  *(.bss.*)
  . = ALIGN(8);
  PROVIDE(_bss_end = .);
 } 

 . = ALIGN(0x10000);

 /* . = 0x80180000; */

	PROVIDE(_mon_end = .);

  /*. = 0x800E0000; */
  . = 0x80120000;

  .scratch_area :
  {
    PROVIDE(scratch_area_start = .);
    *(._scratch_area)
    . += 0x10000;
    PROVIDE(scratch_area_start = .);
  }

  /*. = 0x800ff000;*/ /* the last page before the payload */

  . = 0x8013f000;

  .sanctum_area :
  {
    /* # Sanctum params */
    /* ================ */
    

    /* ## manufacturer_keys : */

    /* 32 Bytes : manufacturer public key */
    PROVIDE( sanctum_m_public_key = . );
    . += 0x20;

    /* 32 Bytes : device public key */
    PROVIDE( sanctum_dev_public_key = . );
    . += 0x20;

    /* 64 Bytes : device secret key */
    PROVIDE( sanctum_dev_secret_key = . );
    . += 0x40;

    /* ## security_monitor_keys : */

    /* 64 Bytes : security monitor hash */
    PROVIDE( sanctum_sm_hash = . );
    . += 0x40;

    /* 32 Bytes : security monitor public key */
    PROVIDE( sanctum_sm_public_key = . );
    . += 0x20;

    /* 64 Bytes : security monitor secret key */
    PROVIDE( sanctum_sm_secret_key = . );
    . += 0x40;

    /* 64 Bytes : security monitor's signature by device */
    PROVIDE( sanctum_sm_signature = . );
    . += 0x40;
  }

  
}

