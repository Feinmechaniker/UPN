UPN Taschenrechner BORIS
========================

Eigentlich verwendet ja kein Mensch mehr einen Taschenrechner. 
Aber da ein wahrer Bastler über die Frage "Wofür soll das gut sein?" erhaben  ist, warum nicht?

Die erste Open-Source-inkarnation (boris4) s.a. (rpn_boris_A328_v1.x.bas) sollte
- UPN (Umgekehrte Polnische Notation) haben
- leicht wissenschaftlich sein (Winkelfunktionen, Logarithmen, ...)
- mit den altmodischen Siebensegmentanzeigen leuchten (LED)
- Halbwegs klein sein
- praktisch verwendbar sein.

Als Prozessor kommen verschiedene ATMega Varianten zum Einsatz, programmiert mit BASCOM. 

Wenig später entstand die programmierbare Variante von Boris (rpn_boris_A328_v2.x.bas).

Später wuchsen dann die Wünsche schneller, 
- eine USB-Schnittstelle, 
- ein SD-Card-Interface und 
- ein mehrzeiliges Display sollten es sein.
Das war dann die Idee für den Boris-Voyager (Boris_Voyager.bas).

Das Projekt basiert auf dem Entwurf eines UPN Taschenrechners von 
Gero.D (www.srswift.de). Dieser Taschenrechner wurde um eine 
UART-Schnittstelle erweitert, um von einem PC externe Programme zu 
laden oder Programme vom Taschenrechner zu sichern. Die Steuerung 
kann  über den Boris-Commander (BC.exe) oder verschiedene 
Kommandozeilenprogramme (Compiler, Decompiler, Terminal) erfolgen. 

Kritik, Vorschläge und Erweiterungen können unter: 
https://www.mikrocontroller.net/topic/465853?goto=new#new 
diskutiert werden.

# verfügbare Kommandos zur Steuerung des Taschenrechners über UART

## Kommando
- 0xAA		- *connect* verbidet den Taschenrechner mit dem PC
- 0x52 		- *read* liest den Programmspeicher des Taschenrechners
- 0x53		- *write* schreibt den Programmspeicher des Taschenrechners

- 0x54 - upload von Files vom PC zum boris im Blockmodus (XMODEM-ähnlich)
- 0x55 - download von Files von boris zum PC im Blockmodus (XMODEM-ähnlich)
- 0x56 - Remote-start eines Programms über die serielle Schnittstelle

