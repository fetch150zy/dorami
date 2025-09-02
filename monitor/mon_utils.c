
void __attribute__((noreturn)) sbi_hart_hang(void)
{
	while (1){
        //
    }
	__builtin_unreachable();
}

void mon_open_osbi(void){
    asm("li t6, 0x3000000; csrs pmpcfg0, t6; fence");
}

void mon_close_osbi(void){
    asm("li t6, 0x3000000; csrc pmpcfg0, t6; fence");
}