	org	0a000h
	seek 00000h
_file_start:
	defb "4952 Protocol Analyzer"

	org 0a016h
	seek 00016h
	defw 003c4h
	defw 00800h

	org 0a01ah
	seek 0001ah
	defb "4952 Hacking the 4952           "

_filesize:
	org 0a102h
	seek 00102h
	defw ((_file_end - _file_start) / 256)-1				; Blocks in file - 1

	defb " HP4952 HAX       4952  "
	defw 00800h
_fileflags:
	defw 00000h							; Flags 0200h is copy protect

	defb "4952 Hacking the 4952           "
