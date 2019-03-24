UPN Taschenrechner BORIS
========================

Das Projekt basiert auf dem Entwurf eines UPN Taschenrechners von 
Gero.D (www.srswift.de). Dieser Taschenrechner wurde um eine 
UART-Schnittstelle erweitert, um von einem PC externe Programme zu 
laden oder Programme vom Taschenrechner zu sichern. Die Steuerung 
erfolgt über den Boris-Commander (BC.exe). Kritik, Vorschläge
und Erweiterungen können unter: 
https://www.mikrocontroller.net/topic/465853?goto=new#new 
diskutiert werden.

# verfügbare Kommandos zur Steuerung des Taschenrechners über UART

## Kommando
- 0xAA		- *connect* verbidet den Taschenrechner mit dem PC
- 0x52 		- *read* liest den Programmspeicher des Taschenrechners
- 0x53		- *write* schreibt den Programmspeicher des Taschenrechners
