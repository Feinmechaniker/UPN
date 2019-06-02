' ****************************************************************************
'
' Boris M
' (One of the last UPN-Taschenrechner)
' Version S 4.0 BASCOM
'
' Copyright (c) 1992-2019 g.dargel <srswift@arcor.de> www.srswift.de
'
' This program is free software: you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation, either version 3 of the License, or
' (at your option) any later version.
'
' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
' See the GNU General Public License for more details.
'
' You should have received a copy of the GNU General Public License
' along with this program. If not, see <http://www.gnu.org/licenses/>.
'
' ****************************************************************************
'
'  "Wissenschaftliche" Variante mit TFT-Display EA DOG-M
'  V2 - Programmierbar
'
'  255 Programmschritte (00-254) im EEPROM (K_num_prg)
'  32 Zahlenspeicher (0-31) im EEPROM  (K_num_mem)
'  16 Unterprogrammebenen mit GOSUB und RETURN
'
'  Updates: Updates: 3.3 Initialversion, basiert auf der V2.17
'                        LCD-Display. groesserer Speicher, Sleep ueber LCD-Beleuchtung, Statuszeile
'                        8x4-Tastenfeld
'                    3.4 Bereichprüfungen der Adressen bei der Eingabe
'                    3.5 Statuszeile, Fehlermeldungen verbessert
'                    3.6 Tastaturabfrage ueberarbeitet
'                    3.7 Geänderte Tastaturbelegung, Befehlscodes für sin u.s.w. geaendert,
'                        HEX-Anzeige und Eingabe
'                    3.8 Neue bedingte Sprungbefehle x<y, x=y x>y, Loop-Befehle
'                    3.9 PAUSE Befehl (1s warten mit Anzeige an), geaenderte Statuszeile im Run-Modus
'                    3.10 Index-Register zum Indirekten Zugriff auf Programm und Zahlenspeicher
'                    3.11 Verschiedene Adressueberpruefungen
'
'----------------------------------------------------------

$regfile = "m328pdef.dat"                                   ' ATmega328-Deklarationen

$prog &HFF , &H62 , &HD9 , &HFF                             ' generated. Take care that the chip supports all fuse bytes.

$crystal = 1000000                                          ' Kein Quarz: 1MHz MHz
$baud = 9600                                                ' Baudrate der UART: 9600 Baud

Osccal = 84                                                 ' Kalibrierung des RC Oscillators, Dieser Wert muss noch hinexperimentiert werden
Echo Off

$hwstack = 196                                              ' hardware stack (32)
$swstack = 196                                              ' SW stack (10)
$framesize = 256                                            ' frame space (40)

$lib "single.lbx"
$lib "double.lbx"
$lib "fp_trig.lbx"

' Hardware/Softwareversion
Const K_version = "5.3.11"                                  '

' Compile-Switch um HP29C-kompatibel zu sein, beim Runterrutschen nach dem Rechnen, wird der Inhalt von Rt erhalten
Const Hp29c_comp = 1
' Const Hp29c_comp = 0 ' Rt wird mit "0" initialisiert

' Compile-Switch ob das Display mit 3.3V (0) oder 5V (1) betrieben wird
Const Dog_5v_comp = 0


' Mit dem folgenden Compile-Switch werden die Blockladefunktionen / Remotestart enabled.
' Diese Funktionen sind nicht kompatibel zum BorisCommander (noch nicht?)
' Compile-Switch fuer eine Alternative Verwendung der Seriellen Schnittstelle (Blockweise, mit Protokoll)
Const Block_communication = 1

#if Block_communication = 1
' Wenn mit Interrupt, dann diese Config
Config Serialin = Buffered , Size = 20
#endif

' SPI-Interface zum DOGM163-Display.
' Wir verwenden die Hardware SPI, also die Pins der B-Ports
' die Tastatur verschiebt sich damit auf die D-Ports

' B1 = CS
' B3 = MOSI
' B4 = MISO
' B5 = SCK
' 5V und GND nach bedarf
' Hintergrundleuchten ebenfalls

' HW-SPI
Config Spi = Hard , Interrupt = Off , Data_order = Msb , Master = Yes , Polarity = High , Phase = 1 , Clockrate = 4 , Noss = 1
Spiinit

' Die Pinbelegungen für das HW-SPI
Dog_cs Alias Portb.1                                        ' Chip select, Low = active
Dog_ds Alias Portb.2                                        ' data select, 0 = commando 1 = daten
Dog_mosi Alias Portb.3
Dog_miso Alias Portb.4
Dog_clk Alias Portb.5

Config Dog_mosi = Output
Config Dog_miso = Input
Config Dog_clk = Output
Config Dog_cs = Output

Set Dog_cs
Dog_miso = 1                                                'pull up on miso

' Tastaturmatrix
' PC4, PC5, PD2-PD7 - Zeilen - Output
' Wir steuern mit einer 0
' unbenutzte Pins mit pullup auf 5v

Ddrd = &B11111111
Portd = &B11111111

' PC0-PC3 - Spalten - Input, PC4 und PC5 - Output

Ddrc = &B00110000
Portc = &B11111111

Ddrb.0 = 1                                                  ' PortB.0 steuert die Display-Beleuchtung
Portb.0 = 1                                                 ' Pullup

' -JG-
' UART-Funktion
Const Uart_sync = &HAA                                      ' Synchron-Byte

' Grunddefinitionen
' Die Anzeige kann was? - Noch umzusetzen
Const S_max_digit = 16                                      ' Wiviel Anzeigestellen hat das Display
Const S_disp_float = 0                                      ' Displaymodus Float
Const S_disp_fix2 = 1                                       ' Displaymodus FIX2
Const S_disp_eng = 2                                        ' Displaymodus "E"
Const S_disp_hm = 3                                         ' Displaymodus H:M
Const S_disp_hex = 4                                        ' Displaymodus hex

' ========================================================================
' Funktions- und Subroutine Deklarationen
' ========================================================================
Declare Sub Polling()                                       ' Interrupt-Routine, Tastaturabfrege und Eingabeinterpretation

Declare Function Inmaxkey() As Byte                         ' Tastaturmatrix abfragen
Declare Function Key2kdo(incode As Byte) As Byte            ' Key decodieren
Declare Function Digit_input(byval Inputkey As Byte) As Byte       ' Unterscheiden Ziffer oder Kommando
Declare Function Needs_adress(inputkey As Byte) As Byte     ' Wieviel Adressziffern braucht das Kommando?
Declare Function Is_transparent(inputkey As Byte) As Byte   ' Transparente Kommandos werden nicht gespeichert, sondern auch im Edit-Mode gleich ausgefuehrt
Declare Function Adress_check(byval Chk_adr As Word) As Byte       ' Check ob adressen erlaubt
Declare Function Cast2byte(byval Dwert As Double) As Byte   ' Umwandlung eines Double-Wertes in ein Byte

' Anzeigefunktionen
Declare Sub Init_st7036()                                   ' Initialisierung der Anzeige, 2-Zeilig Helligkeit, Modus u.s.w.
Declare Sub Sendspi2display(senddata As Byte)               ' Datenschaufel zum Display
Declare Sub Anzeigen()                                      ' Schleife ueber das Anzeigefeld, Umwandlung in Displaycode
Declare Sub Interpr_xy()                                    ' Die Anzeigefunktion, wir interpretieren Rx und Ry
Declare Sub Interpr_reg(byval Reg As Double)                ' Die Anzeigefunktion, wir interpretieren ein Register in das W_st Feld
Declare Sub Show_version()                                  ' Anzeige der Programmversion in in das W_st Register
Declare Sub Beepme()                                        ' Ein kurzes Blinzeln mit der Anzeige
Declare Sub Pause1s()                                       ' 1 Sekunde Pause
Declare Sub Save_w_st()                                     ' Anzeigeregister W_st sichern
Declare Sub Restore_w_st()                                  ' Anzeigeregister W_st zurueckladen
Declare Sub Clear_t_st()                                    ' Statuszeile loeschen
Declare Sub Clear_output()                                  ' Ausgaberegister leeren
Declare Sub Display_error(byval Ec As Byte)                 ' Die Error-Zeichenkette ausgeben
Declare Sub Show_f_key()                                    ' Anzeige: Der F-Key ist aktiv
Declare Sub Display_adress_input()
Declare Sub Display_code()                                  ' Anzeige des Programmspeichers
Declare Sub Display_code_line(byval Code_word As Word)      ' Umrechnen einer Codezeile zur ANzeige und anzeigen
Declare Sub Display_status_line()                           ' Umrechnen einer Codezeile zur ANzeige und anzeigen

Declare Sub Kill_run()                                      ' Programm anhalten
Declare Sub Display_runmode()                               ' Anzeige "run" in der Statuszeile bei Programmabarbeitung
Declare Sub Display_hours(byval Rxwrk As Double)            ' Anzeige im Stundenmodus
Declare Sub Display_hex(byval Rxwrk As Double)              ' Anzeige im Hex-Modus

Declare Function Round_me(byval Dbl_in As Double , Num As Byte) As Double       ' Runden fuer die Anzeige
Declare Function To_digit(byval Input As Byte) As Byte      ' Umwandeln Einstelliger Integer-Zahl nach ASCII
Declare Sub Disp_e_float(byval Dbl_in As Double , Byval Reg As Double)       ' Grosse Float-Anzeige mit "E"

Declare Function Encode_kdo(byval Inputkey As Byte) As String

' Eingabefunktionen
Declare Sub Translate_x()                                   ' uebersetzen wir das Eingaberegister nach x
Declare Sub Clear_input()                                   ' Eingaberegister leeren
Declare Sub Input_number()                                  ' Zahleneingabe ins Eingaberegister
Declare Sub Input_to_rx()                                   ' Den Inhalt von Trans_input nach Rx bringen
Declare Sub Clean_dp_in_input(byval Position As Byte)       ' Alle ggf. schon eingegeben Dezimalpunkte bereinigen

' Bearbeitungsfunktionen
Declare Function Exec_kdo() As Byte                         ' Kommandoausfuehrung, Return 0 = OK, 1 = Fehler
Declare Sub Enter()                                         ' Enter -funktion Der Rechenregister * /
Declare Sub Rolldown()                                      ' Rolldown -funktion Der Rechenregister * /

Declare Sub Update_cache()                                  ' Den Cache in den Eram zurueckschreiben

' -JG-
' UART Funktion
Declare Sub Display_con()                                   ' "Con." Anzeige auf dem Display
Declare Sub Display_load()                                  ' "LoAd" Anzeige auf dem Display
Declare Sub Display_save()                                  ' "SavE" Anzeige auf dem Display
Declare Sub Uart()                                          ' UART Funktion zum PC
Declare Sub File_send()                                     ' Sendefunktio
Declare Sub File_receive()                                  ' Empfangsfunktion

#if Block_communication = 1
Declare Sub Upload_block()                                  ' Protokolliges Empfangen von einem Datenblock mit Pruefsumme und Quittung
Declare Sub Upload_file()                                   ' Protokolliges Empfangen von einer Datei
Declare Sub Download_block(byval Schluss As Byte)           ' Protokolliges Empfangen von einem Datenblock mit Pruefsumme und Quittung
Declare Sub Download_file()                                 ' Protokolliges Empfangen von einer Datei
Declare Sub Download_headerblock(byval Size As Byte)
Declare Sub Run_program()
#endif

Const K_num_mem = 32                                        ' Anzahl der Zahlenspeicher
Const K_num_prg = 255                                       ' Anzahl der Zahlenspeicher


' ========================================================================
' Nun denn: Variablen
' ========================================================================

' 1. Flags
Dim Z_inputflag As Bit                                      ' Es wurde vor dem Kommand bereits mindestens eine Ziffer eingegeben
Dim Sleepflag As Integer

' 2. Rechenregister
Dim Rx As Double
Dim Ry As Double
Dim Rz As Double
Dim Rt As Double
Dim Lstx As Double

' 3. Speicher fuer die Anzeige
Dim I_st(16) As Byte                                        ' Eingabe-Register
Dim T_st(16) As Byte                                        ' Das Anzeige-Register fuer die erste Zeile
Dim V_st(16) As Byte                                        ' Das Anzeige-Register fuer die erste Zeile
Dim W_st(16) As Byte                                        ' Das Anzeige-Register fuer die zweite Zeile

Dim S_st(48) As Byte                                        ' Eine Kopie des Anzeige-Registers
Dim I_pt As Byte                                            ' Eingabe-Pointer

' 4. Arbeitsvariablen
Dim Pressedkey As Byte
Dim Lstkey As Byte
Dim Ziffer_in As Byte
Dim Index As Byte
Dim Adr_input_flag As Byte                                  ' Ein Flag, ob und wieviele Adressen erforderlich sind
Dim X_adresse As Byte                                       ' Die Adresse zum aktuellen Kommando
Dim X_kommando As Byte                                      ' Das aktuelle Kommando
Dim Store_kdo_active As Bit                                 ' STO kann ggf. ein Rechenkommando sein
Dim W_grdrad As Double

Dim Trans_input As Double                                   ' Umgewandelte Zahl aus dem Eingabestring
Dim Bcheck As Byte
Dim Errx As Byte
Dim Inv_key As Bit                                          ' Flag, jemand hat die Zweitbelegung der Tasten angefordert
Dim Index_key As Bit                                        ' Index-Key zum indirekten Speicherzugriff

Dim Rnd_setup As Bit                                        ' Flag, der Zufallszahlengenerator ist initialisiert
Dim ___rseed As Word                                        ' Der Startwert des Zufallszahlengenerators
Dim Intrnd As Word                                          ' Int Ergebnis des Zufallszahlengenerators

' 5. Permanentspeicher
Dim Ee_fixflag As Eram Byte                                 ' Wir haben jetzt auch einen Festkomma-Modus mit 2 Nachkommastellen

Dim Ce_mem(k_num_mem) As Double                             ' Cache fuer den Zahlenspeicher
Dim Fe_mem(k_num_mem) As Byte                               ' Flags, ob eine Speicherzelle geschrieben worden ist
Dim Ee_mem(k_num_mem) As Eram Double                        ' Die persistente Variante des Zahlenspeichers

Dim Ee_program_valid As Eram Byte                           ' Der Inhalt des EEPROM koennte etwas sinnvolles sein
Dim Ee_program(k_num_prg) As Eram Word                      ' Das Programm steht im EEPROM, 255 Speicherzellen 1 Byte code, 1 Byte Adresse

' 7. Für die Programmierung brauchen wir natürlich noch mehr
Dim P_stack(16) As Byte                                     ' Für die Returns bei GOSUB
Dim P_sp As Byte                                            ' Stackpointer, eigentlich ein Index
Dim P_pc As Byte                                            ' Der Programmzeiger, Logisch, 0-254
Dim P_programming As Bit                                    ' Flag ob wir gerade im Auto- oder Programmiermodus sind
Dim P_goflag As Bit                                         ' Flag ob wir gerade das Programm ausfuehren oder interaktiv rechnen
Dim Save_programming As Bit
Dim Save_goflag As Bit

Dim P_heartbeat As Byte                                     ' Flag Zur Schlangensteuerung
Dim Kcode As String * 6
Dim Wrkchar As String * 1

#if Block_communication = 1
Dim G_uart_error As Byte                                    ' Fehlerflag
Dim F_blocknr As Byte                                       ' gelesene Blocknummer
Dim F_nextblock As Byte                                     ' erwarteter naechster Block
Dim F_blockuse As Byte                                      ' Verwendung des Datenblocks
Dim F_blockfolg As Byte                                     ' Es folgt ein weiterer Datenblock
Dim F_blockptr As Byte                                      ' Adresse der Programmspeicherzelle, die geschrieben wird

Dim Zbuffer(16) As Byte                                     ' Lesepuffer der seriellen Schnittstelle
#endif

' ========================================================================
' Kommandocodes
' 48-57 sind Ziffern
' 58-63 sind HEX-ziffern "A"-"F"
' Ab der 65 entstehen sie durch Aufaddieren von K_F_OFFSET = 64
' Obergrenze: 127
' Der Index-Key addiert auf die GOTO uns STORE/RCL-Funktionen ggf. 128 drauf

Const K_nop = 0                                             ' NOP
Const K_plus = 1                                            ' "+"
Const K_minus = 2                                           ' "-"
Const K_mal = 3                                             ' "*"
Const K_durch = 4                                           ' "/"
Const K_point = 5                                           ' "."
Const K_enter = 6                                           ' "Enter"
Const K_store = 7                                           ' STO
Const K_recall = 8                                          ' RCL
Const K_sqrt = 9                                            ' SQRT
Const P_goto = 10                                           '  Programming: GOTO
Const P_gosub = 11                                          '  Programming: GOSUB
Const P_return = 12                                         '  Programming: RETURN
Const K_logn = 13                                           ' LN
Const P_start = 14                                          '  Programming: START / STOP
Const K_clearx = 15                                         ' CX
Const K_xhochy = 16                                         ' x hoch y
Const K_chgxy = 17                                          ' x <-> y

' Rechnende Speicher
Const K_rechn_speicher = 17                                 ' Offset um die Kommandos der rechnenden Speicher aus + - * / zu bestimmen
Const K_stoplus = 18                                        ' STO +
Const K_stominus = 19                                       ' STO -
Const K_stomal = 20                                         ' STO *
Const K_stodurch = 21                                       ' STO /

' Winkelfunktionen ! ACHTUNG geaenderter Code
Const K_sinus = 28                                          ' 28  - SINUS
Const K_cosinus = 29                                        ' 29  - COSINUS
Const K_tangens = 30                                        ' 30  - TANGENS

Const K_hex_a = 58                                          ' Hex A
Const K_hex_b = 59                                          ' Hex B
Const K_hex_c = 60                                          ' Hex C
Const K_hex_d = 61                                          ' Hex D
Const K_hex_e = 62                                          ' Hex E
Const K_hex_f = 63                                          ' Hex F

Const K_f_offset = 64                                       ' Offset fuer die Zweitbelegung

Const K_pause = K_plus + K_f_offset                         ' 65   - Pause, 1s warten mit Display an
Const K_minusx = K_minus + K_f_offset                       ' 66   - 0.0 - x
Const K_rnd = K_mal + K_f_offset                            ' 67   - RND
Const K_einsdrchx = K_durch + K_f_offset                    ' 68   - 1/x
Const K_fix2 = K_point + K_f_offset                         ' 69   - Umschalten Eng -> Fix2 -> H:M
Const K_roll = K_enter + K_f_offset                         ' 70   - Roll Down

Const P_back = K_store + K_f_offset                         ' Programming step back                                  ' STO
Const P_vor = K_recall + K_f_offset                         ' Programming step forward

Const K_quadr = K_sqrt + K_f_offset                         ' 73   - Quadrat
Const P_ifbig = P_goto + K_f_offset                         ' 74   - If x groesser 0 goto
Const P_ifequal = P_gosub + K_f_offset                      ' 75   - If x gleich 0 goto
Const P_ifless = P_return + K_f_offset                      ' 76   - If x kleiner 0 goto

Const P_ifxbigy = 52 + K_f_offset                           ' 116   - If x groesser y goto "4"
Const P_ifxequaly = 53 + K_f_offset                         ' 117   - If x gleich y goto "5"
Const P_ifxlessy = 54 + K_f_offset                          ' 118   - If x kleiner y goto "6"

Const P_loop7 = 55 + K_f_offset                             ' 116   - If $7++ > 0 goto "7"
Const P_loop8 = 56 + K_f_offset                             ' 117   - If $8++ > 0 goto "8"
Const P_loop9 = 57 + K_f_offset                             ' 118   - If $9++ > 0 goto "9"

Const K_ehochx = K_logn + K_f_offset                        ' 77   - e hoch x
Const P_auto = P_start + K_f_offset                         ' 78   - Umschaltung Run / Program
Const P_nop = K_clearx + K_f_offset                         ' 79  - No Operation    "cx"
Const K_pi = K_xhochy + K_f_offset                          ' 80  - Pi    "über x hoch y"
Const K_lstx = K_chgxy + K_f_offset                         ' 81   - Lstx,

Const K_grd = 48 + K_f_offset                               ' 112  - grd / rad toggle   "0"
Const K_int = 49 + K_f_offset                               ' 113  - INT   "1"
Const K_frac = 50 + K_f_offset                              ' 114  - FRAC  "2"
Const K_abs = 51 + K_f_offset                               ' 115  - ABS   "3"

Const K_asin = K_sinus + K_f_offset                         ' 92  - ARCUS SINUS
Const K_acos = K_cosinus + K_f_offset                       ' 93  - ARCUS COSINUS
Const K_atan = K_tangens + K_f_offset                       ' 94  - ARCUS TANGENS

Const K_index = 60                                          ' 60  - Index

Const K_zweit = 128                                         '

' Zeichencodes, sind in dieser Version weitgehend ASCII
Const D_char_dp = &H2E                                      ' "."
Const D_space = &H20                                        ' Leerzeichen
Const D_char_eq = &H3D                                      ' "="

#if Block_communication = 1
Const D_char_pfr = &H7E                                     ' Pfeil rechts
Const D_char_pfl = &H7F                                     ' Pfeil links
#endif

Const Pi_k = 3.141592653589793238462643383279502

' ========================================================================
' Hauptprogramm
' ========================================================================

' ========================================================================
' Initialisierung
' ========================================================================

#if Block_communication = 1
' Die UART im Binaermodus
' Ist wahrscheinlich nicht erforderlich, aber der Klarheit wegen
Open "Com1:9600,8,N,1" For Binary As #1
#endif

' Initialisieren der Flags und Hilfsvariablen
Lstkey = 0
Sleepflag = 0
Inv_key = 0
Rnd_setup = 0
Z_inputflag = 0
Store_kdo_active = 0
Index_key = 0

' Die EEPROM-Inhalte koennten nach dem Brennen Unsinn enthalten
' If Ee_fixflag <> 1 And Ee_fixflag <> 2 And Ee_fixflag <> 3 And Ee_fixflag <> 4 Then Ee_fixflag = 0

If Ee_program_valid <> 77 Then
  Ee_program_valid = 77
  Ee_fixflag = 0
  ' Die Programmspeicher muessen zurueckgesetzt werden
  For Index = 1 To K_num_prg
     Ee_program(index) = K_nop
  Next Index
End If

' Die Permanentspeicher muessen in den Cache gelesen werden, dabei werden sie u.U. gleich initialisiert
For Index = 1 To K_num_mem
  Rx = Ee_mem(index)
  Bcheck = Checkfloat(rx)
  Errx = Bcheck And 5
  If Errx > 0 Then
     Rx = 0.0                                               ' Initialisierung bei Lesen vor dem Schreiben
     Fe_mem(index) = 1                                      ' veraendert-Flag
  Else
     Fe_mem(index) = 0                                      ' Unveraendert-Flag
  End If
  Ce_mem(index) = Rx
Next Index

W_grdrad = Pi_k / 180.0                                     ' Beim Einschalten verwenden wir grd

' Für den Programmiermodus muessen auch ein paar Variablen initialisiert werden

P_stack(1) = 0                                              ' Beim Einschalten geht es bei 0 los
P_sp = 1
P_pc = 0                                                    ' Beim Einschalten geht es bei 0 los
P_programming = 0                                           ' 0 =  Auto, 1 = Programmiermodus
P_goflag = 0                                                ' Beim EInschalten sind wir im Interaktiv-Modus

P_heartbeat = 0

' Initialisieren der UPN-Rechenregister
Rx = 0.0
Ry = 0.0
Rz = 0.0
Rt = 0.0
Lstx = 0.0

' Ausgaberegister leeren und Display initialisieren
Call Clear_output
Call Clear_input                                            ' Eingaberegister leeren

Call Init_st7036
Call Show_version
Call Anzeigen

' 3 Sekunden lang die Version anzeigen
Waitms 3000

' Jetzt den Timer einstellen,
On Timer0 Polling                                           'Interrupt-Routine für Timer0-Overflow
Config Timer0 = Timer , Prescale = 1024                     'Timer-Takt ist Quarz/1024
' Rechnen wir mal, wir haben 1k Ticks pro sekunde,
' Vorteiler 1024 ergibt 1024 Interrupts pro Sekunde
' wenn wir 40 mal in der Sekunde pollen wollen, wäre der Timer auf 256-25 zu setzen

Timer0 = 231
' Timer0 = 206

Enable Timer0
Enable Interrupts


' Hier geht der Ernst des Lebens jetzt los
Call Interpr_xy()
Call Anzeigen

Do                                                          'Hauptschleife
      Waitms 1000

#if Block_communication = 1
      'get a char from the UART
      If Ischarwaiting() = 1 Then Call Uart                 ' Ist was auf der Seriellen Schnittstelle?
#else
      ' -JG-
      If Ucsr0a.rxc0 = 1 Then Call Uart                     ' Zeichen auf der UART-Schnittstelle empfangen
#endif

Loop

End

' ========================================================================
' Programmende ist hier!
' Es folgen Funktionen und Unterprogramme
' ========================================================================

' ========================================================================
' Interrupt zum Tastaturpolling 20 mal in der Sekunde
' ========================================================================
Sub Polling()

  Local Tmatrix As Byte
  Local Is_ziffer As Byte
  Local Transp_kdo As Byte
  Local Code_word As Word
  Local Saved_ppc As Byte
  Local Retval As Byte
  Local Pc As Byte                                          ' Der P_pc zaehlt ab 0, die Feldadressen bei BASCOM beginnen bei 1
  Local Adr_check_flag As Byte
  Local Aerr_flg As Byte

  Pc = P_pc + 1

  Tmatrix = Inmaxkey()                                      ' Abfrage der Tastaturmatrix, Return Tastenposition
  Pressedkey = Key2kdo(tmatrix)                             ' Umwandeln in einen Tastaturcode

  Bcheck = Checkfloat(rx)
  Errx = Bcheck And 5

  If P_goflag = 1 Then                                      ' Wenn ein Programm ausgeführt wird

      Store_kdo_active = 0

      Code_word = Ee_program(pc)

      X_kommando = High(code_word)                          ' Trennung Code von Adresse
      X_adresse = Low(code_word)

      ' Der Index-Key addiert auf den Funktionscode (der Einfachkeit halber) 128 drauf
      If X_kommando > 127 Then
         X_kommando = X_kommando - 128
         If X_adresse < K_num_mem Then
            Incr X_adresse                                  ' BASCOM index ab 1
            X_adresse = Cast2byte(ce_mem(x_adresse))        ' Index aufloesen, Im Fehlerfall wird Errx erhoeht
         Else
            Incr Errx
         End If
      End If

      If Pressedkey <> 0 Or Errx <> 0 Then                  ' Jeder Tastendruck oder Fehler stoppt das laufende Programm
         Call Kill_run()
         If Errx <> 0 Then Call Display_error( "X")
         Goto Weiter
      End If

      Saved_ppc = P_pc                                      ' Zur Erkennung, ob ein GOTO ausgefuehrt wurde

      Is_ziffer = Digit_input(x_kommando)

      If Is_ziffer = 1 Then                                 ' Eine Ziffer wurde Im Programmspeicher gelesen
         Pressedkey = X_kommando
         Call Input_number()
      Else
         Retval = Exec_kdo()
         If Retval <> 0 Then
            P_goflag = 0                                    ' Ein Fehler haelt die Programmausfuehrung an
            Goto Weiter
         End If
      End If

      If Saved_ppc = P_pc Then Incr P_pc
      If P_pc >= K_num_prg Then                             ' Bei Ueberlauf Fehlermeldung
        Call Display_error( "P")
        Goto Weiter
      End If

      Call Interpr_xy()
      Call Anzeigen

      Sleepflag = 0

  Else                                                      ' Interaktiv, kein laufendes Programm

      If Pressedkey > 0 And Sleepflag > 1200 Then           ' Ein Knopf im Schlafmodus gedrueckt
          Pressedkey = 0
          Sleepflag = 0
          Portb.0 = 1                                       ' Wakeme()
          Goto Weiter
      End If

      If Pressedkey = 0 Then Goto Nokey

      ' Ein beliebiger Key loescht einen Error-Status, macht aber nix weiter
      If Errx > 0 Then
         Rx = Lstx
         Call Kill_run()
         Goto Weiter
      End If

      If Pressedkey = K_zweit Then                          ' F (= Zweitbelegung) wurde gerade gedrueckt
         Inv_key = Not Inv_key                              ' Toggle
         Call Show_f_key()                                  ' Anzeige umschalten "F"
         Call Anzeigen
         Goto Weiter
      End If

      If Inv_key = 1 And Pressedkey > 0 Then                ' Zweitbelegung war gewuenscht
         Pressedkey = Pressedkey + K_f_offset
         Inv_key = 0
      End If

      ' Hier ist jetzt zu unterscheiden,
      ' Moegliche Eingaben sind:
      '  * Ziffern und Punkte, das können Zahleneingaben oder Adressen sein
      '  * Kommandos, die gehen entweder in den Programmspeicher oder an den Interpreter.
      '               Aber erst, wenn Sie komplett sind
      '               Kommandos gibt es in 3 Formen
      '                   * Operationen (haben keine Adressen)
      '                   * Manche Einstellbefehle z.B. FIX brauchen einen Parameter
      '                   * Speicheraktionen haben eine einstellige Adresse (0-31)
      '                     und zwischen Kdo und Adresse ggf. eine Operation + - * /
      '                   * Sprungbefehle haben eine zweistellige Adresse (00-254)

      Is_ziffer = Digit_input(pressedkey)

      If Is_ziffer = 1 Then                                 ' Eine Ziffer wurde gedrueckt, das kann adresse oder Eingabe sein
         If Adr_input_flag = 0 Then                         ' Es laeuft gerade keine Adresseingabe
             X_adresse = 0
             Index_key = 0
             Call Input_number()
         Else                                               ' Adresseingabe
            If Pressedkey <> K_point Then                   ' Der Punkt wird bei der Eingabe einer Adresse einfach ignoriert
              If Pressedkey = K_index Then
                Adr_input_flag = 2                          ' Indexfunktion geht auf die Zahlenspeicher, wir brauchen 2 Adressstellen
                Adr_check_flag = 2
                X_adresse = 0                               ' Index setzt die Adresseingabe zurueck
                Index_key = 1
              Else
                X_adresse = X_adresse * 10
                X_adresse = X_adresse + Pressedkey
                X_adresse = X_adresse - "0"                 ' Der  Keycode der Zahlen  ist ASCII
                Decr Adr_input_flag
                If Adr_input_flag = 0 Then Is_ziffer = 0    ' Wenn die Adresse Komplett ist, betrachten wir die Eingabe als ein Kommando
              End If
              Call Display_adress_input()
              Call Anzeigen
            End If
         End If
         Store_kdo_active = 0
      Else                                                  ' Keine Ziffer sondern ein Kommando

         If Pressedkey = K_store Then                       ' STORE, es koennte sein, dass wir ein "Zwischenkommando" fuer den rechnenden Speicher brauchenRechnende Speicher brauchen noch eine Eingabe
            Store_kdo_active = 1
         End If

         ' Die Rechenenden Speicher, Wir berechnen das neue Kommando
         If Pressedkey >= K_plus And Pressedkey <= K_durch Then
            If Store_kdo_active = 1 Then
               Pressedkey = K_rechn_speicher + Pressedkey
               Store_kdo_active = 0
            End If
         End If

         X_adresse = 0
         X_kommando = Pressedkey                            ' Umwandeln Byte -> Word

         Adr_input_flag = Needs_adress(pressedkey)          ' Die naechsten x ziffern gehen in die Adressfelder
         Adr_check_flag = Adr_input_flag                    ' Merken zur spaeteren Pruefung

         If Adr_input_flag <> 0 Then
             Call Display_adress_input()
             Call Anzeigen
             ' Call Beepme
         Else
             Call Display_status_line()
             Call Anzeigen
         End If

      End If

      If Adr_input_flag <> 0 Then Goto Weiter               ' Noch gehen Adresseingaben ab

      ' Wir haben groessere Adressbereiche, wir muessen diese hier abpruefen,
      Aerr_flg = Adress_check(x_adresse)
      If Aerr_flg = 1 Then                                  ' Adressfehler!
         Pressedkey = 0
         Store_kdo_active = 0
         Goto Weiter
      End If

      Transp_kdo = Is_transparent(pressedkey)               ' Manche Kommandos muessen auch im Programmiermodus ausgefuehrt werden

      ' SO, hier ist jetzt alles aufbereitet.
      ' Jetzt muss nur noch:
      '   a) der Prozessor gerufen werden mit X_kommando und X_adresse
      '   oder b) der schmuseputz in den Programmspeicher geschrieben werden. In diesem Fall muss die Ziffer natürlich dazu

      If P_programming = 0 Or Transp_kdo = 1 Then           ' 0 =  Auto, 1 = Programmiermodus
         If Is_ziffer = 0 Then                              ' Die letzte Eingabe war ein Kommando oder die Adresseingabe ist abgeschlossen
            If Index_key = 1 Then
              If X_adresse < K_num_mem Then
                 Incr X_adresse                             ' BASCOM index ab 1
                 X_adresse = Cast2byte(ce_mem(x_adresse))   ' Index aufloesen, Im Fehlerfall wird Errx erhoeht
              Else
                 Incr Errx
              End If
              Index_key = 0
            End If

            If Errx <> 0 Then
               Call Display_error( "I")
               Goto Weiter
            End If

            Retval = Exec_kdo()

            If Retval <> 0 Then Goto Weiter

         End If
      Else                                                  ' Programmiermodus
         If Pressedkey <> K_index Then                      ' Der Index-Key selbst kommt nicht in das Programm
            If Is_ziffer = 0 Then
               If X_kommando = P_nop Then X_kommando = K_nop       ' Wir versuchen, die NOPs im Speicher als 00 stehen zu haben
               ' Die Eingabe soll in den Programmspeicher
               If Index_key = 1 Then
                 X_kommando = X_kommando + 128              ' Index-Bit im Programmsoeicher setzen
                 Index_key = 0                              '
               End If
               Code_word = X_kommando * 256                 ' Platz lassen fuer den Adressteil
               Code_word = Code_word + X_adresse            '
            Else                                            ' Auch ziffern sollen in den Programmspeicher
               Code_word = Pressedkey * 256                 ' Das Adressfeld brauchen wir bei Ziffern nicht
            End If

            Ee_program(pc) = Code_word

            Disable Interrupts
            Call Kill_run()
            Waitms 700
            Incr P_pc
            If P_pc >= K_num_prg Then P_pc = 0              ' Wir rollen ueber
            Enable Interrupts
            Call Interpr_xy()
         End If
         ' Call Beepme
      End If
      Call Anzeigen
      Sleepflag = 0

  End If

  Goto Weiter

  Nokey:

    ' wenn wir nichts zu tun haben, koennen wir ja den Cache aufraeumen
    Call Update_cache()

    ' Wenn lange kein Knopf gedrueckt wurde, schalten wir die Anzeige auf "Sleep",
    ' Alles aus, nur der allerletzte Dezimalpunkt ist an
    ' Der Timeout (etwa 1 Minute ist hier hartcodiert
    If Inv_key = 0 Then                                     ' Wenn wir auf die Eingabe nach dem "F" warten, schlafen wir nicht
       If Sleepflag = 1200 Then
          Portb.0 = 0                                       ' Dosleep()
       End If

       Incr Sleepflag

       If Sleepflag > 1200 Then
           Sleepflag = 1201
       End If
    End If

  Weiter:

  ' Im Run-Modus können wir schneller sein!
  If P_goflag = 1 Then
     Timer0 = 253                                           '256-3
     ' Timer0 = 231                                           '256-25
  Else
     Timer0 = 231                                           '256-25
     ' Timer0 = 206                                           '256-50
  End If
End Sub Polling


' ========================================================================
' Pruefung, ob eine Adresse im Limit ist, ggf. Error
' Input: Adresse, wir pruefen nur auf das Limit der Programmspeicher,
'                 die Zahlenspeicher werden in der Exec_kdo Proc geprueft
' Return
' 0 = OK,
' 1 = Error
' ========================================================================
Function Adress_check(byval Chk_adr As Word) As Byte

   Adress_check = 0                                         ' default, alles OK

   If Chk_adr > K_num_prg Then
         Call Display_error( "A")
         Adress_check = 1
   End If

End Function Adress_check


' ========================================================================
' Anhalten eines laufenden Programms erzwingen
' ========================================================================
Sub Kill_run()
    P_goflag = 0
    Call Interpr_xy()
    Call Anzeigen
End Sub Kill_run


' ========================================================================
' War die eingabe eine Ziffer oder ein Kommando?
' ========================================================================
Function Digit_input(byval Inputkey As Byte) As Byte
   Digit_input = 0
   If Inputkey >= "0" And Inputkey <= "9" Then Digit_input = 1
   If Inputkey = K_point Then Digit_input = 1               ' Der Dezimalpunkt
   If Inputkey = K_index Then Digit_input = 1
   If Inputkey >= K_hex_a And Inputkey <= K_hex_f Then Digit_input = 1       ' Hex-Ziffern
End Function Digit_input


' ========================================================================
' Umwandlung einer Double-Zahl in ein Byte (zur Adressarithmetik)
' prueft nebenbei, ob die Adresse im Limit ist und setzt den Errx
' ========================================================================
Function Cast2byte(byval Dwert As Double) As Byte

Local Cdx_adr As Double
Local Cdx_a As Long                                         ' fuer cast des Registerinhaltes auf eine Adresse

   Cast2byte = 0

   Cdx_adr = Round(dwert)                                   ' Index aufloesen
   Cdx_adr = Int(cdx_adr)                                   ' Cast auf Byte, sollte so funktionieren
   Cdx_a = Cdx_adr
   If Cdx_a > K_num_prg Then
      Incr Errx
   Else
      Cast2byte = Cdx_a Mod 256
   End If

End Function Cast2byte


' ========================================================================
' Wieviel Adressziffern braucht das Kommando?
' ========================================================================
Function Needs_adress(inputkey As Byte) As Byte
   Needs_adress = 0                                         ' Normalerweise brauchen wir keine Adresse
   Select Case Inputkey

      ' Zahlenspeicher
      Case K_store
        Needs_adress = 2
      Case K_recall
        Needs_adress = 2

      ' Rechnende Speicher
      Case K_stoplus
        Needs_adress = 2
      Case K_stominus
        Needs_adress = 2
      Case K_stomal
        Needs_adress = 2
      Case K_stodurch
        Needs_adress = 2

      ' Sprungbefehle
      Case P_goto
        Needs_adress = 3
      Case P_gosub
        Needs_adress = 3
      Case P_ifless
        Needs_adress = 3
      Case P_ifequal
        Needs_adress = 3
      Case P_ifbig
        Needs_adress = 3

      Case P_ifxlessy
        Needs_adress = 3
      Case P_ifxequaly
        Needs_adress = 3
      Case P_ifxbigy
        Needs_adress = 3

      Case P_loop7
        Needs_adress = 3
      Case P_loop8
        Needs_adress = 3
      Case P_loop9
        Needs_adress = 3

      ' Einstellungen
      Case K_fix2
        Needs_adress = 1
      Case K_grd
        Needs_adress = 1

      End Select
End Function Needs_adress


' ========================================================================
' Ist das eingegeben Kommando ein "transparentes"?
' d.h. es wird nicht im Programmspeicher abgelegt, sondern gleich ausgeführt
' ========================================================================
Function Is_transparent(inputkey As Byte) As Byte
   Is_transparent = 0
   ' Entscheidend ist pressedkey (global)
   If Inputkey = P_back Then Is_transparent = 1
   If Inputkey = P_vor Then Is_transparent = 1
   If Inputkey = P_auto Then Is_transparent = 1
End Function Is_transparent


' ========================================================================
' Zahleneingabe ins Eingaberegister
' in Pressedkey steht der ASCII-Wert der gedrueckten Taste, zwischen "0" und "9"
' Oder ein "."
' oder ein code K_hex_a bis K_hex_f
' ========================================================================
Sub Input_number()

Local N_3 As Byte

    If Pressedkey = K_index Then Goto No_input_dp           ' In der Zahleneingabe ist der Index-Key unsinnig
    If Ee_fixflag = S_disp_hex And Pressedkey = K_point Then Goto No_input_dp

    If Z_inputflag = 0 And P_programming = 0 Then           ' Wenn wir in die Zahleneingabe umschalten schieben wir die X-Eingabe eine Zeile hoch
       For N_3 = 1 To 16
           V_st(n_3) = W_st(n_3)
       Next N_3
    End If

    Z_inputflag = 1
    If I_pt = 2 And I_st(1) = "0" And Pressedkey <> K_point Then I_pt = 1       ' "0"-Verriegelung d.h 00 am Anfang ist unsinn

    If I_pt <= 16 Then
       If Pressedkey = K_point And I_pt > 1 Then
          Call Clean_dp_in_input(i_pt)
       End If

       If Pressedkey = K_point And I_pt = 1 Then
          I_st(1) = "0"
          Incr I_pt
       End If

       If Pressedkey = K_point Then
          I_st(i_pt) = D_char_dp
       Else
          If Pressedkey >= K_hex_a And Pressedkey <= K_hex_f Then
             I_st(i_pt) = Pressedkey + 7                    ' K_hex_a -> "A"
          Else
             I_st(i_pt) = Pressedkey
          End If
       End If

       Incr I_pt
    End If

    ' If Ee_fixflag = S_disp_hex Then                         ' HEX - Anzeige
    '     Call Clean_dp_in_input(i_pt)                        ' Hier stoeren Die Dezimalpunkte nur
    ' End If

    ' waehrend der Eingabe geben wir das Eingaberegister selbst aus, aber nur wenn im Run-Mode
    If P_programming = 0 Then
       For N_3 = 1 To I_pt
           W_st(17 -n_3) = I_st(n_3)
       Next N_3
       For N_3 = I_pt To 16
           W_st(17 -n_3) = D_space
       Next N_3
    Else
       Call Beepme
    End If
No_input_dp:
End Sub Input_number


' ========================================================================
' Es kann nur einen Punkt in der Eingabe geben!
' ========================================================================
Sub Clean_dp_in_input(byval Position As Byte)               ' Alle ggf. schon eingegeben Dezimalpunkte bereinigen
    Local Lp As Byte
    Local Np As Byte
    'I_pt ist der Globale Zeiger auf die Eingabeposition.
    ' Wenn wir einen DP geloescht haben, muss der vermindert werden
    For Lp = 1 To Position
       If I_st(lp) = D_char_dp Then
          While Lp < Position
             Np = Lp + 1
             I_st(lp) = I_st(np)
             Incr Lp
          Wend
          Decr I_pt
       End If
    Next Lp
End Sub Clean_dp_in_input


' ========================================================================
' Aktualisieren des Rx-Registers aus dem globelen Trans_input-Speicher
' ========================================================================
Sub Input_to_rx()
    Local Vdoubl As Double
    Rx = Trans_input
    If Ee_fixflag = S_disp_hm Then                          ' Wenn wir im Stundenmodus sind, Eingabe entsprechend korrigieren. 1.30 bedeutet 1.5 h
       Vdoubl = Frac(rx)
       Rx = Int(rx)
       Vdoubl = Vdoubl / 0.6
       Rx = Rx + Vdoubl
    End If
    If Ee_fixflag = S_disp_hex Then                         ' Wenn wir im Hex-modus sind, nur Integer
       Rx = Int(rx)
    End If
End Sub Input_to_rx


' ========================================================================
' Eingaberegister leeren
' ========================================================================
Sub Clear_input()
   Local N As Byte
   For N = 1 To 16
      I_st(n) = D_space
   Next N
   I_pt = 1                                                 ' Wohin geht die naechste Eingabe?
   Ziffer_in = 0
   I_st(i_pt) = "0"
End Sub Clear_input


' ========================================================================
' Ausgaberegister leeren
' ========================================================================
Sub Clear_output()
   Local N As Byte
   For N = 1 To 16
      T_st(n) = D_space                                     ' ASCII Leerzeichen
      V_st(n) = D_space                                     ' ASCII Leerzeichen
      W_st(n) = D_space                                     ' ASCII Leerzeichen
   Next N
End Sub Clear_output


' ========================================================================
' Anzeige: F-Taste gedrueckt
' ========================================================================
Sub Show_f_key()
     If Inv_key = 1 Then
          Call Save_w_st
          Call Clear_output
          Call Display_status_line()
          T_st(16) = "F"
          T_st(15) = D_space
          T_st(14) = D_space
          T_st(13) = D_space
     Else
          Call Restore_w_st
     End If
End Sub Show_f_key

' ========================================================================
' Wir zeigen in der T_st - Zeile allerlei Systeminfos an
' ========================================================================
Sub Display_status_line()
    Local Tmpnr As Byte
    Local N As Byte

    Call Clear_t_st()

    If W_grdrad = 1.0 Then                                  ' Winkelfunktionen in Bogenmass?
      T_st(16) = "r"
      T_st(15) = "a"
    Else
      T_st(16) = "g"
      T_st(15) = "r"
    End If
    T_st(14) = "d"

    T_st(12) = "P"
    T_st(11) = "c"
    T_st(10) = D_char_eq

    ' Zahl nach Ziffer
    T_st(9) = To_digit(p_pc \ 100)
    Tmpnr = P_pc Mod 100
    T_st(8) = To_digit(tmpnr \ 10)
    T_st(7) = To_digit(p_pc Mod 10)

    T_st(3) = D_char_eq
    If P_goflag = 1 Then                                    ' Wenn ein Programm ausgeführt wird  Anzeige Stacklevel
       T_st(5) = "S"
       T_st(4) = "L"
       T_st(2) = To_digit(p_sp \ 10)
       T_st(1) = To_digit(p_sp Mod 10)
    Else                                                    ' Sonst Displaymodus
       T_st(5) = "D"
       T_st(4) = "M"
       T_st(2) = To_digit(ee_fixflag)
    End If
End Sub Display_status_line

' ========================================================================
' Wir zeigen in der T_st - Zeile Das Kommando und die eingegebene Adresse
' ========================================================================
Sub Display_adress_input()
    Local N As Byte
    Local Code_word As Word
    Local Tmpnr As Byte

    For N = 1 To 16
      S_st(n) = W_st(n)                                     ' W_st sichern
    Next N

    Code_word = X_kommando * 256                            ' Platz lassen fuer den Adressteil
    Code_word = Code_word + X_adresse                       '

    Call Display_code_line(code_word)                       ' Code-Zeile berechnen

    For N = 1 To 16
      T_st(n) = W_st(n)                                     ' In die T-Zeile uebertragen
      W_st(n) = S_st(n)                                     ' W_st rekonstruieren
    Next N

    T_st(16) = D_space
    T_st(15) = &H2D
    T_st(14) = D_char_pfr
    T_st(13) = D_space

    ' Im Index-Modus muessen wir es ein wenig korrigieren
    If Index_key = 1 Then
       T_st(4) = "I"
       T_st(3) = "x"
                                              ' :
       ' Und nun die Anzeige
       Tmpnr = X_adresse \ 10
       If Tmpnr > 0 Then
          T_st(2) = To_digit(tmpnr)
       End If
       T_st(1) = To_digit(x_adresse Mod 10)
    End If

End Sub Display_adress_input

' ========================================================================
' Den String "Error" in die Statuszeile der Anzeige schreiben
' Ec = Errorcode zum Anzeigen
' ========================================================================
Sub Display_error(byval Ec As Byte)

   Local N As Byte

   Call Clear_t_st()

   T_st(10) = "E"
   T_st(9) = "r"
   T_st(8) = "r"
   T_st(7) = "o"
   T_st(6) = "r"
   T_st(5) = D_space                                        ' ASCII Leerzeichen
   T_st(4) = Ec

   P_goflag = 0                                             ' Fehler fuehren immer zum Programmhalt
   Call Anzeigen

End Sub Display_error


' ========================================================================
' Die Anzeigefunktion, wir interpretieren Ry und Rx in das V_st und W_st Register
' Im Programmiermodus wird der zum PC gehörige Programmspeicher angezeigt
' ========================================================================
Sub Interpr_xy()
   Local N As Byte

   If P_goflag = 0 Then                                     ' Anzeige nur, wenn wir nicht gerade ein Programm lauren lassen
      If P_programming = 0 Then                             ' interaktiver Auto-modus

         Call Display_status_line()


         Call Interpr_reg(ry)

         For N = 1 To 16
            V_st(n) = W_st(n)
         Next N

         Call Interpr_reg(rx)
      Else
         Call Display_code()
      End If
  Else
     Call Display_runmode()
  End If

End Sub Interpr_xy


' ========================================================================
' Die Anzeigefunktion, wir interpretieren Reg in das W_st Register
' ========================================================================
Sub Interpr_reg(byval Reg As Double)

  Local Ii As Byte
  Local Ij As Byte
  Local Lastpos As Byte

  Local Rxs1 As String * 32
  Local Snumber As Byte

  Local Fixi As Double
  Local Fixint As Long
  Local Fixdiff As Long
  Local Fixfrac As Double

  Local Rxwrk As Double

   ' Ist hier wahrscheinlich unnoetig, weil es bereits im Polling gemacht wird
   Bcheck = Checkfloat(reg)
   Errx = Bcheck And 5

   ' Im Fix-Modus haben wir einen kleineren Anzeigebereich
   ' -99999.99 <= Reg <= 999999.99
   If Ee_fixflag = S_disp_fix2 Then
      If Reg <= -1000000000.0 Then Incr Errx
      If Reg >= 10000000000.0 Then Incr Errx
   End If

   ' Im H:M-Modus haben wir einen kleineren Anzeigebereich
   ' -999999.99 <= Reg <= 999999.99
   If Ee_fixflag = S_disp_hm Then
      If Reg <= -1000000.0 Then Incr Errx
      If Reg >= 1000000.0 Then Incr Errx
   End If

   ' Im hex-Modus haben wir einen kleineren Anzeigebereich
   ' -FFFFFFF <= Reg <= 7FFFFFFF
   If Ee_fixflag = S_disp_hex Then
      If Reg < -268435455 Then Incr Errx
      If Reg > 2147483647 Then Incr Errx
   End If


   ' Wenn kein Error - Ausgeben
   If Errx = 0 Then

      For Ii = 1 To 16
         W_st(ii) = D_space                                 ' ASCII Leerzeichen
      Next Ii

      Rxwrk = Abs(reg)                                      ' Das Vorzeichen machen wir dann selbst
      If Reg < 0.0 Then
          Lastpos = 15
          W_st(16) = "-"
      Else
          Lastpos = 16
      End If

      If Ee_fixflag = S_disp_fix2 Then                      ' Fix2 -Anzeige

         Rxwrk = 100.0 * Rxwrk                              ' Zwei Feste Nachkommastellen
         Fixi = Int(rxwrk)
         Fixint = Fixi
         Fixfrac = Rxwrk - Fixi
         If Fixfrac > 0.5 Then Incr Fixint                  ' Einfache Rundungsregel
         For Ii = 1 To 2
             Fixdiff = Fixint Mod 10
             W_st(ii) = Str(fixdiff)
             Fixint = Fixint \ 10
             If Fixint = 0 And Ii > 2 Then
               Ii = 16
             End If
         Next Ii
         W_st(3) = D_char_dp
         For Ii = 4 To Lastpos
             Fixdiff = Fixint Mod 10
             W_st(ii) = Str(fixdiff)
             Fixint = Fixint \ 10
             If Fixint = 0 And Ii > 3 Then
               Ii = Lastpos
             End If
         Next Ii

      End If

      If Ee_fixflag = S_disp_float Then                     ' Float-Anzeige

        Ij = Lastpos

        If Rxwrk < 100000000000.0 And Rxwrk > 0.000000001 Then       ' Kleine Float-Anzeige ohne E

           Rxwrk = Round_me(rxwrk , Ij)

           Fixi = Int(rxwrk)
           Fixint = Fixi                                    ' Cast auf Integer
           Fixfrac = Rxwrk - Fixi
           ' Fixdiff = Fixfrac                             ' Cast auf integer

           If Fixint > 0 Then                               ' Die Zahl ist groesser als 0
              ' Aufarbeiten der Vorkommastellen
              Rxs1 = Str(fixint)
              Snumber = Len(rxs1)

              Snumber = Ij - Snumber                        ' Die Einerstelle
              Incr Snumber

              For Ii = Snumber To Ij
                 Fixdiff = Fixint Mod 10
                 W_st(ii) = Str(fixdiff)
                 Fixint = Fixint \ 10
              Next Ii

              Ij = Snumber - 1

              W_st(ij) = D_char_dp
              Decr Ij
           Else
              W_st(ij) = "0"
              Decr Ij
              W_st(ij) = D_char_dp
              Decr Ij
           End If

           While Ij > 0 And Fixfrac > 0.0                   ' Es sind noch stellen in der Anzeige verfügbar
               Fixfrac = Fixfrac * 10.0
               Fixi = Int(fixfrac)
               Fixint = Fixi
               W_st(ij) = To_digit(fixint)
               Fixfrac = Fixfrac - Fixi
               Decr Ij
           Wend

           ' Wir machen das Minus selbst!
           If Reg < 0.0 Then
              W_st(16) = "-"
           End If
        Else                                                ' Grosse Float-Anzeige mit "E"
            Call Disp_e_float(rxwrk , Reg)
        End If

        If Reg = 0.0 Then
            W_st(16) = "0"
            W_st(15) = D_char_dp
        End If
      End If

      If Ee_fixflag = S_disp_eng Then                       ' Float-Anzeige mit "E"
        Call Disp_e_float(rxwrk , Reg)
        If Reg = 0.0 Then
            W_st(16) = "0"
            W_st(15) = D_char_dp
        End If
      End If

      If Ee_fixflag = S_disp_hm Then                        ' H:M - Anzeige
         Call Display_hours(rxwrk)
      End If

      If Ee_fixflag = S_disp_hex Then                       ' HEX - Anzeige
         Call Display_hex(rxwrk)
         If Reg < 0.0 Then
              W_st(12) = "-"
         End If
      End If

   Else                                                     ' Zeichenkette "Error" Ausgeben
     Call Display_error(d_space)
   End If

End Sub Interpr_reg


' ========================================================================
Sub Display_hours(byval Rxwrk As Double)

  Local Hmstunden As Long
  Local Hmminuten As Long

  Local Fixi As Double
  Local Fixint As Long
  Local Fixdiff As Long
  Local Fixfrac As Double

  Local Ii As Byte

  ' Der Wert im Reg sind Stunden mit komma, rechnen wir erst mal in Minuten um:
  Rxwrk = Rxwrk * 60.0                                      ' Minuten
  Fixi = Int(rxwrk)
  Fixint = Fixi
  Fixfrac = Rxwrk - Fixi
  If Fixfrac > 0.5 Then Incr Fixint                         ' Einfache Rundungsregel

  ' Minuten und Stunden wie gewohnt
  Hmstunden = Fixint \ 60
  Hmminuten = Fixint Mod 60

  ' Und nun die Anzeige
  ' Die Minuten, 2 Nachkommastellen
  W_st(1) = Hmminuten Mod 10
  W_st(1) = Str(w_st(1))
  W_st(2) = Hmminuten \ 10
  W_st(2) = Str(w_st(2))
  W_st(3) = ":"

  For Ii = 4 To 10
      Fixdiff = Hmstunden Mod 10
      W_st(ii) = Str(fixdiff)
      Hmstunden = Hmstunden \ 10
      If Hmstunden = 0 Then                                 ' Fertig
         Incr Ii
         If W_st(16) = "-" Then W_st(ii) = "-"              ' Das "-" muss an die richtige Stelle weiter vor
         Ii = 16
      End If
  Next Ii
  W_st(16) = "h"                                            ' ein "h" an der ersten Stelle
End Sub Display_hours

' ========================================================================
Sub Display_hex(byval Rxwrk As Double)

  Local Hexstring As String * 16

  Local Regnum As Long
  Local Qpos As Byte
  Local Zpos As Byte
  Local Hlen As Byte
  Local Pchar As String * 1
  Local Rxx As Double
  Local Nullflag As Byte

  Nullflag = 0

  Rxwrk = Rxwrk + 0.5                                       ' einfache rundungsregel

  Rxx = Int(rxwrk)
  Regnum = Rxx

  Hexstring = Hex(regnum)
  Hlen = Len(hexstring)

  W_st(16) = "h"
  W_st(15) = "e"
  W_st(14) = "x"

  For Qpos = Hlen + 1 To 12
      W_st(qpos) = D_space
  Next Qpos

  Zpos = 1

  For Qpos = Hlen To 1 Step -1
      Pchar = Mid(hexstring , Zpos , 1)
      If Nullflag = 1 Or Pchar <> "0" Then                  ' Fuehrende Nullen entfernen
        Nullflag = 1
        W_st(qpos) = Pchar
      Else
        W_st(qpos) = D_space
      End If
      Incr Zpos
  Next Qpos

  If W_st(1) = D_space Then W_st(1) = "0"

End Sub Display_hex


' ========================================================================
' Busy - Anzeige bei der Programmabarbeitung
' ========================================================================
Sub Display_runmode()
  If P_heartbeat = 0 Then
    Call Display_status_line()
    T_st(16) = "r"
    T_st(15) = "u"
    T_st(14) = "n"
    Call Anzeigen()
  End If

  Incr P_heartbeat
  If P_heartbeat > 7 Then P_heartbeat = 0

End Sub Display_runmode


' ========================================================================
' Anzeige Programmspeicher in 3 Zeilen
' eine vor und eine Zeile nach dem P_pc
' ========================================================================
Sub Display_code()

   Local Dispadr As Byte
   Local Nc As Byte
   Local S_p_pc As Byte
   Local Code_word As Word

   ' P_pc Ist Eigentlich Der Logische Befehlszaehler , Von 0-254
   ' K_num_prg ist die Anzahl der Programmspeicher also 255

   S_p_pc = P_pc                                            ' Merken!

   If P_pc = 0 Then                                         ' Rollover, wir Zeigen Zeile 254 mit an
      P_pc = K_num_prg
   End If

   ' Ab hier steht in P_pc der BASCOM-Index des Programmspeichers
   ' Eigentlich muessten wir P_pc jetzt fuer die vorherige Zeile um 1 verringern
   ' und dann um 1 (BASCOM-Index) erhoehen

   Code_word = Ee_program(p_pc)
   Call Display_code_line(code_word)

   For Nc = 1 To 16
       T_st(nc) = W_st(nc)
   Next Nc

   Incr P_pc
   If P_pc > K_num_prg Or P_pc = 0 Then P_pc = 1            ' Wir rollen einfach über
   Code_word = Ee_program(p_pc)                             ' Eigentlich muessten wir das ding jetzt um 1 verringern und dann um 1 erhoehen
   Call Display_code_line(code_word)
   W_st(16) = D_char_pfr

   For Nc = 1 To 16
       V_st(nc) = W_st(nc)
   Next Nc

   Incr P_pc
   If P_pc > K_num_prg Or P_pc = 0 Then P_pc = 1            ' Wir rollen einfach über
   Code_word = Ee_program(p_pc)                             ' Eigentlich muessten wir das ding jetzt um 1 verringern und dann um 1 erhoehen
   Call Display_code_line(code_word)

   P_pc = S_p_pc                                            ' gemerkten Wert zuruecksetzen

End Sub Display_code


' ========================================================================
' Umrechnen einer Codezeile und Zur Anzeige vorbereiten
' ========================================================================
Sub Display_code_line(byval Code_word As Word)

  Local Pcode As Byte
  Local Adress As Byte
  Local N_adress As Byte

  Local L_ppc As Byte
  Local N_1 As Byte
  Local N_2 As Byte
  Local Spidata As Byte

  Local Tmpnr As Byte

  Local Strlen As Byte
  Local Qpos As Byte
  Local Zpos As Byte

  Local Indexflag As Byte

  For N_1 = 1 To 16
    W_st(n_1) = D_space
  Next N_1

  Pcode = High(code_word)                                   ' Trennung Code von Adresse

  If Pcode > 127 Then
      Pcode = Pcode - 128
      Indexflag = 1
  Else
      Indexflag = 0
  End If

  ' Und nun die Anzeige

  L_ppc = P_pc - 1                                          ' Wir haben zum Auslesen den P_pc illegalerweise um 1 erhoeht
  W_st(15) = To_digit(l_ppc \ 100)
  Tmpnr = L_ppc Mod 100
  W_st(14) = To_digit(tmpnr \ 10)
  W_st(13) = To_digit(l_ppc Mod 10)

  ' Und hier den Codestring einbauen

  Kcode = Encode_kdo(pcode)

  Strlen = Len(kcode)
  Zpos = 11

  For Qpos = 1 To Strlen
      Wrkchar = Mid(kcode , Qpos , 1)
      W_st(zpos) = Wrkchar
      Decr Zpos
  Next Qpos

  N_adress = Needs_adress(pcode)

  Adress = Low(code_word)

  If N_adress > 0 Then
    If Indexflag = 0 Then
        W_st(4) = &H3A                                      ' :
        ' Und nun die Anzeige
        Tmpnr = Adress \ 100
        If Tmpnr > 0 Then
           W_st(3) = To_digit(tmpnr)
        End If
        Tmpnr = Adress Mod 100
        Tmpnr = Tmpnr \ 10
        If Tmpnr > 0 Or W_st(3) <> D_space Then
           W_st(2) = To_digit(tmpnr)
        End If
    Else                                                    ' Index-Mode
        W_st(4) = "I"
        W_st(3) = "x"
        ' Und nun die Anzeige
        Tmpnr = Adress \ 10
        If Tmpnr > 0 Then
           W_st(2) = To_digit(tmpnr)
        End If
    End If
    W_st(1) = To_digit(adress Mod 10)
  End If
End Sub Display_code_line


' ========================================================================
' Anzeige im Eng-Modus (mit "E")
' ========================================================================
Sub Disp_e_float(byval Dbl_in As Double , Byval Reg As Double)       ' Grosse Float-Anzeige mit "E"

  Local Iii As Byte
  Local Ijj As Byte
  Local Rxs2 As String * 32
  Local Strindex As Byte
  Local Posc As String * 1
  Local Posn As Byte


  Rxs2 = Str(dbl_in)
  Strindex = Len(rxs2)

  If Reg < 0.0 Then
             Ijj = 15
  Else
             Ijj = 16
  End If

  For Iii = 1 To Strindex
      Posc = Mid(rxs2 , Iii , 1)
      If Posc = "E" Then                                    ' Egal, wieviele Stellen noch kommen, der E-Kram muss hinpassen
               Ijj = Strindex - Iii
               Incr Ijj
      End If
      Posn = Posc

      If Ijj > 0 Then
         W_st(ijj) = Posn
         Decr Ijj
      End If
  Next Iii
End Sub Disp_e_float


' ========================================================================
' Runden einer Double-Zahl auf num stellen
' ========================================================================
Function Round_me(byval Dbl_in As Double , Num As Byte) As Double

  Local Wrkstr As String * 32
  Local Wrkfixdbl As Double
  Local Wrkfix As Long
  Local Wrk_len As Byte
  Local Wrk_rx As Double

  Local Anz_vork As Byte
  Local Anz_nachk As Byte
  Local Si As Byte

  Wrkfixdbl = Int(dbl_in)
  Wrkfix = Wrkfixdbl

  Wrkstr = Str(wrkfix)
  Anz_vork = Len(wrkstr)
  Anz_nachk = Num - Anz_vork

  Wrk_rx = Dbl_in

  For Si = 1 To Anz_nachk
    Wrk_rx = Wrk_rx * 10.0
  Next Si

  Wrk_rx = Round(wrk_rx)

  For Si = 1 To Anz_nachk
    Wrk_rx = Wrk_rx * 0.1
  Next Si

  Round_me = Wrk_rx

End Function Round_me


Function To_digit(byval Input As Byte) As Byte
  If Input >= 0 And Input <= 9 Then
     To_digit = Input + "0"
  Else
     To_digit = &H0D
  End If
End Function To_digit

' ========================================================================
' Eine weitere Anzeigefunktion, wir interpretieren den Versionsstring in das W_st Register
' Der Versionsstring hat bis zu 7 Zeichen und besteht aus Ziffern und Punkten
' Const K_version = "4.1.11"                                  '
' ========================================================================
Sub Show_version()

  Local Vsrx As String * 16
  Local Vii As Byte
  Local Vij As Byte
  Local Vposc As String * 1
  Local Vinputlen As Byte

  Vsrx = K_version

  W_st(16) = "b"
  W_st(15) = "o"
  W_st(14) = "r"
  W_st(13) = "i"
  W_st(12) = "s"
  W_st(11) = D_space

  Vinputlen = Len(vsrx)

  For Vii = 1 To Vinputlen
    Vij = 10 - Vii
    Vposc = Mid(vsrx , Vii , 1)
    W_st(vij) = Vposc
  Next Vii

  Incr Vinputlen

  For Vii = Vinputlen To 16
    Vij = 10 - Vii
    W_st(vij) = D_space
  Next Vii

  ' W_st(1) = &H3D

End Sub Show_version


' ========================================================================
' uebersetzen wir das Eingaberegister nach x
' ========================================================================
Sub Translate_x()
   Local Stelle As Double
   Local Below_one As Double
   Local Decflag As Byte
   Local N_1 As Byte                                        ' Index im Eingabefeld
   Local B_st As Byte

   Trans_input = 0.0                                        ' Hier bauen wir die Zahl auf
   Below_one = 0.0
   Decflag = 0                                              ' Ein Dezimalpunkt wurde erkannt, es folgen Nachkommastellen

   For N_1 = 1 To I_pt -1
        B_st = I_st(n_1) - "0"
        If B_st > 9 Then B_st = B_st - 7                    ' Hex-Ziffern
        Stelle = B_st
         If I_st(n_1) = D_char_dp Then                      ' Diese Stelle hat einen Dezimalpunkt
           Below_one = 1.0
           Decflag = 1
        Else
           If Decflag = 0 Then                              ' Normale Ziffern vor dem Komma
              If Ee_fixflag = S_disp_hex Then               ' Wenn wir im Hex-modus sind
                 Trans_input = Trans_input * 16
              Else
                 Trans_input = Trans_input * 10
              End If
              Trans_input = Trans_input + Stelle
           Else                                             ' Nachkommastellen
              If Ee_fixflag <> S_disp_hex Then              ' Wenn wir im Hex-modus sind, nur Integer
                 Below_one = Below_one / 10.0
                 Stelle = Stelle * Below_one
                 Trans_input = Trans_input + Stelle
              End If
           End If
        End If
   Next N_1
End Sub Translate_x



' ========================================================================
' Ausgaberegister Retten
' ========================================================================
Sub Save_w_st()
   Local N As Byte

   For N = 1 To 16
      S_st(n) = W_st(n)
   Next N
   For N = 17 To 32
      S_st(n) = V_st(n - 16)
   Next N
   For N = 33 To 48
      S_st(n) = T_st(n - 32)
   Next N
End Sub Save_w_st

' ========================================================================
' Ausgaberegister Rekonstruieren
' ========================================================================
Sub Restore_w_st()
   Local N As Byte

   For N = 1 To 16
      W_st(n) = S_st(n)
   Next N
   For N = 17 To 32
      V_st(n - 16) = S_st(n)
   Next N
   For N = 33 To 48
      T_st(n - 32) = S_st(n)
   Next N
End Sub Restore_w_st


' ========================================================================
' Statuszeile t_st bereinigen
' ========================================================================
Sub Clear_t_st()
   Local N As Byte

   For N = 1 To 16
      T_st(n) = D_space
   Next N
End Sub Clear_t_st()


' ========================================================================
' Kurzes Blinzeln mit der Anzeige um unsichtbare Kommandos bemerkbar zu machen
' ========================================================================
Sub Beepme()
   If P_goflag = 0 Then                                     ' Nur im Interaktiven Modus
      Disable Interrupts
      Portb.0 = 0                                           ' Dosleep()
      Waitms 100
      Portb.0 = 1                                           ' Wakeme()
      Enable Interrupts
   End If
End Sub Beepme


' ========================================================================
' Kurze Pause (1s) Anzeige bleibt an
' ========================================================================
Sub Pause1s()
   Disable Timer0

   Save_goflag = P_goflag
   Save_programming = P_programming

   P_goflag = 0
   P_programming = 0

   Call Interpr_xy()
   T_st(16) = "P"
   T_st(15) = "1"
   T_st(14) = "s"
   Call Anzeigen()

   Waitms 1000

   Portb.0 = 1
   Call Display_status_line()
   Call Anzeigen()

   P_goflag = Save_goflag
   P_programming = Save_programming

   Timer0 = 231
   Enable Timer0
End Sub Pause1s


' ========================================================================
' Schleife ueber das Anzeigefeld,
' Input sind die Anzeigeregister t_st (STatus) v_st (Ry) und w_st(Rx)
' ========================================================================
Sub Anzeigen()

   Local N_1 As Byte
   Local N_2 As Byte
   Local Spidata As Byte
   Local Dispadr As Byte

   Dispadr = &B10000000                                     ' Wir schreiben erst mal in die Kleinen Zeichen
   Call Sendspi2display(dispadr)                            ' Schreibposition waehlen

   Dog_ds = 1                                               ' Jetzt kommen wirkliche Zeichen!

   ' Die Statuszeile
   For N_1 = 1 To 16
      N_2 = 17 - N_1                                        ' Schleife über die einzelnen Zeichen und Ausgeben zum Display
      ' Hier jetzt noch der Geist
      Spidata = T_st(n_2)
      Call Sendspi2display(spidata)
   Next N_1

   Dog_ds = 0

   Dispadr = &B10000000 + 16                                ' Wir schreiben erst mal in die Grossen Zeichen
   Call Sendspi2display(dispadr)                            ' Schreibposition waehlen

   Dog_ds = 1                                               ' Jetzt kommen wirkliche Zeichen!

   For N_1 = 1 To 16
      N_2 = 17 - N_1                                        ' Schleife über die einzelnen Zeichen und Ausgeben zum Display
      ' Hier jetzt noch der Geist
      Spidata = V_st(n_2)
      Call Sendspi2display(spidata)
   Next N_1

   Dog_ds = 0

   Dispadr = &B10000000 + 32                                ' Wir schreiben erst mal in die Grossen Zeichen
   Call Sendspi2display(dispadr)                            ' Schreibposition waehlen

   Dog_ds = 1                                               ' Jetzt kommen wirkliche Zeichen!

   For N_1 = 1 To 16
      N_2 = 17 - N_1                                        ' Schleife über die einzelnen Zeichen und Ausgeben zum Display
      ' Hier jetzt noch der Geist
      Spidata = W_st(n_2)
      Call Sendspi2display(spidata)
   Next N_1

   Dog_ds = 0

End Sub Anzeigen

' ========================================================================
' Initialisierung der Anzeige, 3-Zeilig Helligkeit, Modus u.s.w.
' ========================================================================
Sub Init_st7036()                                           ' contr 0...3
   Local Spidata As Byte

   Waitms 100                                               ' Vor der Initialisierung warten bis wirklich bereit

   Dog_ds = 0

   Spidata = &H39 : Call Sendspi2display(spidata)           ' 8bit data, Code page 1

#if Dog_5v_comp = 1
   Spidata = &H1D : Call Sendspi2display(spidata)           ' 3 Zeilen Display
   Spidata = &H50 : Call Sendspi2display(spidata)           ' Kontrast
   Spidata = &H6C : Call Sendspi2display(spidata)           ' Spannungsfolger
   Spidata = &H7C : Call Sendspi2display(spidata)           ' Kontrast
#else
   Spidata = &H15 : Call Sendspi2display(spidata)           ' 3 Zeilen Display
   Spidata = &H55 : Call Sendspi2display(spidata)           ' Kontrast
   Spidata = &H6E : Call Sendspi2display(spidata)           ' Spannungsfolger
   Spidata = &H72 : Call Sendspi2display(spidata)           ' Kontrast
#endif

   ' Spidata = &H0F : Call Sendspi2display(spidata)           ' Display an, Cursor an, Blink

   Spidata = &H38 : Call Sendspi2display(spidata)           ' Befehlstabelle 0
   Spidata = &H0C : Call Sendspi2display(spidata)           ' Display an, Cursor off, Blink off
   Spidata = &H01 : Call Sendspi2display(spidata)           ' Display putzen ' Das braucht mglw laenger!
   Spidata = &H06 : Call Sendspi2display(spidata)           ' Cursor Auto incr

   Waitms 2

End Sub Init_st7036


Sub Sendspi2display(senddata As Byte)
   Dog_cs = 0                                               ' Select Display
   Spiout Senddata , 1                                      ' 8bit data
   Waitus 30                                                ' Die meisten Kommandos brauchen 26 us
   Dog_cs = 1                                               ' DeSelect Display
End Sub Sendspi2display


' ========================================================================
' Ein Kommando wurde gedrueckt, fuehren es aus und interpretieren das x-Register
' - Wenn es das erste Kommando nach einer Zahleneingabe war, uebersetzen wir est das Eingaberegister nach x
' ========================================================================
Function Exec_kdo() As Byte
    Local Wrk_fix_flag As Byte

    Local L_adr As Byte
    Local L_code As Word
    Local L_cmd As Byte
    Local Pc As Byte                                        ' Index zum Zugriff auf den Programmspeicher, P_PC zaehlt ab 0, PC ab 1
    Local Memcont As Double
    Local Aerr_flg As Byte

    Exec_kdo = 0                                            ' Default: OK

    ' Wir haben dynamische Adressen, wir muessen diese hier abpruefen,
    Aerr_flg = Adress_check(x_adresse)
    If Aerr_flg = 1 Then                                    ' Adressfehler!
          Exec_kdo = 1
          Goto No_execution
    End If

    ' Verbereiten der Adressdaten (Zahlenspeicher)
    L_adr = X_adresse + 1                                   ' Arbeitsadresse, In BASCOM geht der Index ab 1

    If Z_inputflag = 1 Then                                 ' Vor dem Kommando wurden Ziffern eingegeben, wir muessen die Eingabe nach x uebersetzen
       If X_kommando = K_clearx Then                        ' Löschen während der Zahleneingabe, hat nur Auswirkungen auf das Eingaberegister, nicht auf Rx
            Call Clear_input                                ' Eingaberegister leeren
            Call Clear_output
            Call Anzeigen
            Goto Finish_kdo
       Else
          Call Translate_x
          Call Enter
          Call Input_to_rx
       End If
       ' Z_inputflag = 0                                      ' Wir haben die eingegebenen Zahlen verwurstet
    End If

    ' Machen wir uns mal an die Kommandoausfuehrung,
    ' X_kommando ist der auszufuehrende Befehl
    Select Case X_kommando
      Case K_plus                                           ' "+"
         Lstx = Rx
         Rx = Rx + Ry
         Call Rolldown
      Case K_minus                                          ' "-"
         Lstx = Rx
         Rx = Ry - Rx
         Call Rolldown
      Case K_minusx                                         ' 0.0 - x
         Lstx = Rx
         Rx = 0.0 - Rx
      Case K_mal                                            ' "*"
         Lstx = Rx
         Rx = Ry * Rx
         Call Rolldown
      Case K_rnd                                            ' RND
         Lstx = Rx
         If Rnd_setup = 0 Then
            ___rseed = Sleepflag
            Rnd_setup = 1
         End If
         Intrnd = Rnd(10000)
         Rx = Intrnd
         Rx = Rx / 10000.0 :
      Case K_durch                                          ' "/"
         Lstx = Rx
         Rx = Ry / Rx
         Call Rolldown
      Case K_einsdrchx                                      ' 1/x
         Lstx = Rx
         Rx = 1.0 / Rx
      Case K_enter                                          ' "Enter"
         If Z_inputflag = 0 Then
             Call Enter
             ' Call Beepme
         End If
         Call Beepme
      Case K_fix2                                           ' Umschalten Anzeigemodus Float -> Fix2 -> -> Eng -> H:M -> Hex ...
         If X_adresse > 4 Then X_adresse = 0
         Ee_fixflag = X_adresse
         Call Beepme
      Case K_roll                                           ' Roll Down
         Lstx = Rx
         Rx = Ry
         Ry = Rz
         Rz = Rt
         Rt = Lstx
      Case K_store                                          ' STO
         If L_adr > 0 And L_adr <= K_num_mem Then
            Ce_mem(l_adr) = Rx
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      ' Rechnende Speicher
      Case K_stoplus                                        ' STO +
         If L_adr > 0 And L_adr <= K_num_mem Then
            Memcont = Ce_mem(l_adr) + Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stominus                                       ' STO -
         If L_adr > 0 And L_adr <= K_num_mem Then
            Memcont = Ce_mem(l_adr) - Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stomal                                         ' STO *
         If L_adr > 0 And L_adr <= K_num_mem Then
            Memcont = Ce_mem(l_adr) * Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stodurch                                       ' STO /
         If L_adr > 0 And L_adr <= K_num_mem Then
            Memcont = Ce_mem(l_adr) / Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_recall                                         ' RCL
         If L_adr > 0 And L_adr <= K_num_mem Then
            Call Enter
            Rx = Ce_mem(l_adr)
         Else
            Call Display_error( "A")
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_sqrt                                           ' SQRT
         Lstx = Rx
         Rx = Sqr(rx)
      Case K_quadr                                          ' Quadrat
         Lstx = Rx
         Rx = Rx * Rx
      Case K_sinus                                          ' SIN
         Lstx = Rx
         Rx = Rx * W_grdrad
         Rx = Sin(rx)                                       '
      Case K_asin                                           ' ArcusSinus
         Lstx = Rx
         Rx = Asin(rx)                                      '
         Rx = Rx / W_grdrad
      Case K_cosinus                                        ' COS
         Lstx = Rx
         Rx = Rx * W_grdrad
         Rx = Cos(rx)                                       '
      Case K_acos                                           ' ArcusCosinus
         Lstx = Rx
         Rx = Acos(rx)                                      '
         Rx = Rx / W_grdrad
      Case K_tangens                                        ' TAN
         Lstx = Rx
         Rx = Rx * W_grdrad
         Rx = Tan(rx)                                       '
      Case K_atan                                           ' ArcusTangens
         Lstx = Rx
         Rx = Atn(rx)                                       '
         Rx = Rx / W_grdrad
      Case K_logn                                           ' LN
         Lstx = Rx
         Rx = Log(rx)
      Case K_ehochx                                         ' e hoch x
         Lstx = Rx
         Rx = Exp(rx)
      Case K_clearx                                         ' Cx  - bekommt eine Spezialbehandlung direkt in der Tastenroutine
         If Z_inputflag = 0 Then                            ' Unmotiviertes Loeschen, vorher waren keine Zahleneingaben
            Lstx = Rx
            Rx = 0.0
            Call Beepme
         ' Else
         '   Z_inputflag = 0                                 ' Enter und Lstx - Behandlung nur, wenn als Kommando ausserhalb der Zifferneingabe
         End If
      Case K_xhochy                                         ' x hoch y
         Lstx = Rx
         ' Rx = log(Rx)
         ' Rx = Rx * Ry
         ' Rx = exp(Rx)
         Rx = Rx ^ Ry
         Call Rolldown
      Case K_chgxy                                          ' x <-> y
         Lstx = Rx
         Rx = Ry
         Ry = Lstx
      Case K_lstx                                           ' Lstx
         Call Enter
         Rx = Lstx
         Lstx = Ry
      Case K_grd
         If X_adresse > 1 Then X_adresse = 0
         If X_adresse = 0 Then                              ' grd
            W_grdrad = Pi_k / 180.0                         ' Winkelfunktionen in Grad
         Else                                               ' rad
            W_grdrad = 1.0                                  ' Winkelfunktionen in Bogenmass
         End If
         Call Beepme
      Case K_pi                                             ' Pi
         Call Enter
         Lstx = Rx
         Rx = Pi_k
      Case K_int                                            ' INT
         Lstx = Rx
         Rx = Int(rx)
      Case K_frac                                           ' FRAC
         Lstx = Rx
         Rx = Frac(rx)
      Case K_abs                                            ' ABS
         Lstx = Rx
         Rx = Abs(rx)
      Case P_auto                                           ' Umschalten zwischen Programmier- und Auto-Modus
           P_programming = Not P_programming
      Case P_back                                           ' Ein Schritt rueckwaerts im Programmspeicher
           If P_pc = 0 Then P_pc = K_num_prg
           If P_pc > 0 Then Decr P_pc
      Case P_vor                                            ' Ein Schritt vorwarets im Programmspeicher
           Incr P_pc
           If P_pc >= K_num_prg Then P_pc = 0               ' Wir rollen einfach über
      Case P_goto                                           ' Den Programmzeiger auf die Adresse stellen
           P_pc = X_adresse
           Call Beepme
      Case P_gosub
           If P_sp < 16 Then
              Incr P_sp                                     '
              P_stack(p_sp) = P_pc
              P_pc = X_adresse
           Else
              Call Display_error( "S")
              ' P_goflag = 0
              P_sp = 1
              Exec_kdo = 1
           End If
           Call Beepme
      Case P_return
           P_pc = P_stack(p_sp)
           Incr P_pc                                        ' Wenn sich der P_cp ändert, incrementiert die Automatik den P_pc nicht, daher hier explizit
           If P_sp > 1 Then
              Decr P_sp
           Else
              Call Display_error( "S")
              ' P_goflag = 0
              Exec_kdo = 1
           End If                                           ' Errorcode = "S"
           Call Beepme
      Case P_ifless                                         ' If x kleiner 0 goto
           If Rx < 0.0 Then P_pc = X_adresse
      Case P_ifequal                                        ' If x gleich 0 goto
           If Rx = 0.0 Then P_pc = X_adresse
      Case P_ifbig                                          ' If x groesser 0 goto
           If Rx > 0.0 Then P_pc = X_adresse
      Case P_ifxlessy                                       ' If x kleiner y goto
           If Rx < Ry Then P_pc = X_adresse
      Case P_ifxequaly                                      ' If x gleich y goto
           If Rx = Ry Then P_pc = X_adresse
      Case P_ifxbigy                                        ' If x groesser y goto
           If Rx > Ry Then P_pc = X_adresse
      Case P_loop7                                          ' The small For Next Loop, if $07 > 0 then incr P07; goto X_adresse
            If Ce_mem(8) > 0.0 Then
               Ce_mem(8) = Ce_mem(8) - 1.0
               Fe_mem(8) = 1                                ' Cache als modifiziert markieren
               P_pc = X_adresse
            End If
      Case P_loop8                                          ' The small For Next Loop, ($08)
            If Ce_mem(9) > 0.0 Then
               Ce_mem(9) = Ce_mem(9) - 1.0
               Fe_mem(9) = 1
               P_pc = X_adresse
            End If
      Case P_loop9                                          ' The small For Next Loop, ($09)
            If Ce_mem(10) > 0.0 Then
               Ce_mem(10) = Ce_mem(10) - 1.0
               Fe_mem(10) = 1
               P_pc = X_adresse
            End If
      Case P_start                                          ' Start / Stop der Programmausfuehrung
           P_goflag = Not P_goflag
           If P_goflag = 1 Then
              Pc = P_pc + 1
              L_code = Ee_program(pc)
              L_cmd = High(l_code)                          ' Trennung Code von Adresse
              If L_cmd = P_start Then                       ' Ein P_start waehrend des Laufes bedeutet: Erst mal halt, aber dann mglw. weiter, also p_pc incrementieren
                 Incr P_pc
                 Call Interpr_xy()
                 Exec_kdo = 1                               ' Ein wenig wie Error, wenn wir dann im Polling weitermachen direkt zum weiter
              Else
                 P_sp = 1                                   ' Stackpointer zurücksetzen bei Programmstart
              End If
           End If
           Call Beepme
      Case K_nop
           Call Beepme
      Case P_nop                                            ' tu nix, im Programmspeicher ist da eine 0 oder 254 besser
           Call Beepme
      Case K_pause                                          ' 1 Sekunde warten, anzeige an
           Call Pause1s
      End Select


No_execution:
    X_kommando = 0
    X_adresse = &HFF

Finish_kdo:
    ' Das Kommando koennte den Inhalt von "Rx" geändert haben, wir uebertragen den Inhalt in die Anzeige
    Call Interpr_xy()

    Z_inputflag = 0                                         ' Kommando abgeschlossen, jetzt koennen wieder Ziffern kommen
    Store_kdo_active = 0
    Call Clear_input                                        ' Eingaberegister leeren

End Function Exec_kdo



' ========================================================================
' Enter -funktion Der Rechenregister * /
' ========================================================================
Sub Enter()                                                 ' Enter -funktion Der Rechenregister * /
    Rt = Rz
    Rz = Ry
    Ry = Rx
End Sub Enter


' ========================================================================
' Rolldown -funktion Der Rechenregister * /
' ========================================================================
Sub Rolldown()                                              ' Rolldown -funktion Der Rechenregister * /
 Ry = Rz
 Rz = Rt
#if Hp29c_comp = 0
 Rt = 0.0                                                   ' Da streiten sich die UPN-Goetter, soll "T" beim Rolldown geloescht werden oder nicht?
#endif
End Sub Rolldown


' ========================================================================
' Decodieren des Keycodes zu Ziffern und Kommandos
' Die Codierung ist ziemlich haemdsaermlich, die Ziffern haben ihren ASCII-Code,
' Die Kommandos zaehlen einfach hoch, "F" macht dann noch mal K_F_OFFSET drauf (in der Polling-Routine)
' ========================================================================
Function Key2kdo(incode As Byte) As Byte
   Key2kdo = 0                                              ' Default, nokey
   Select Case Incode
     Case 1
        Key2kdo = K_enter                                   ' "Enter"
     Case 2
        Key2kdo = K_chgxy                                   ' x <-> y
     Case 3
        Key2kdo = K_recall                                  ' RCL
     Case 4
        Key2kdo = K_store                                   ' STO

     Case 5
        Key2kdo = K_plus                                    ' "+"
     Case 6
        Key2kdo = K_minus                                   ' "-"
     Case 7
        Key2kdo = K_mal                                     ' "*"
     Case 8
        Key2kdo = K_durch                                   ' "/"

     Case 9
        Key2kdo = K_clearx                                  ' CX
     Case 10
        Key2kdo = "3"                                       ' 51
     Case 11
        Key2kdo = "6"                                       ' 54
     Case 12
        Key2kdo = "9"                                       ' 57

     Case 13
        Key2kdo = "0"                                       ' 48
     Case 14
        Key2kdo = "2"                                       ' 50
     Case 15
        Key2kdo = "5"                                       ' 53
     Case 16
        Key2kdo = "8"                                       ' 56

     Case 17
        Key2kdo = K_point                                   ' "."
     Case 18
        Key2kdo = "1"                                       ' 49
     Case 19
        Key2kdo = "4"                                       ' 52
     Case 20
        Key2kdo = "7"                                       ' 55

     Case 21
        Key2kdo = K_sqrt                                    ' SQRT
     Case 22
        Key2kdo = K_tangens                                 ' "Tangens"
     Case 23
        Key2kdo = P_return                                  ' RETURN
     Case 24
        Key2kdo = P_start                                   ' START / STOP

     Case 25
        Key2kdo = K_xhochy                                  ' x hoch y
     Case 26
        Key2kdo = K_cosinus                                 ' "Cosinus"
     Case 27
        Key2kdo = P_gosub                                   ' GOSUB
     Case 28
        Key2kdo = K_index                                   ' "Index"

     Case 29
        Key2kdo = K_logn                                    ' LN
     Case 30
        Key2kdo = K_sinus                                   ' "Sinus"
     Case 31
        Key2kdo = P_goto                                    ' GOTO
     Case 32
        Key2kdo = K_zweit                                   ' "F" - Zweitbelegung der Tasten

   End Select


   ' im HEX-Darstellungsmodus bekommen die Sinus-tan und ln-sqrt eine andere Funktion,
   ' nämlich der Zifferneingabe für A-F

   If Ee_fixflag = S_disp_hex Then                          ' Wenn wir im Hex-modus sind, nur Integer
     Select Case Incode
       Case 21
          Key2kdo = K_hex_c                                 ' "C"
       Case 22
          Key2kdo = K_hex_f                                 ' "F"
       Case 25
          Key2kdo = K_hex_b                                 ' "B"
       Case 26
          Key2kdo = K_hex_e                                 ' "E"
       Case 29
          Key2kdo = K_hex_a                                 ' "A"
       Case 30
          Key2kdo = K_hex_d                                 ' "D"
     End Select
   End If
End Function Key2kdo


' ========================================================================
' Umwandeln eines symbolischen Kommandos in eine Zeichenkette
' ========================================================================
Function Encode_kdo(byval Inputkey As Byte) As String
   Encode_kdo = "NOP"

   Select Case Inputkey
     Case 48
          Encode_kdo = "0"
     Case 49
          Encode_kdo = "1"
     Case 50
          Encode_kdo = "2"
     Case 51
          Encode_kdo = "3"
     Case 52
          Encode_kdo = "4"
     Case 53
          Encode_kdo = "5"
     Case 54
          Encode_kdo = "6"
     Case 55
          Encode_kdo = "7"
     Case 56
          Encode_kdo = "8"
     Case 57
          Encode_kdo = "9"
     Case K_nop
          Encode_kdo = "NOP"
     Case K_plus
          Encode_kdo = "+"
     Case K_minus
          Encode_kdo = "-"
     Case K_mal
          Encode_kdo = "*"
     Case K_durch
          Encode_kdo = "/"
     Case K_point
          Encode_kdo = "."
     Case K_enter
          Encode_kdo = "ENTER"
     Case K_store
          Encode_kdo = "STO"
     Case K_recall
          Encode_kdo = "RCL"
     Case K_sqrt
          Encode_kdo = "SQRT"
     Case P_goto
          Encode_kdo = "GOTO"
     Case P_gosub
          Encode_kdo = "GOSUB"
     Case P_return
          Encode_kdo = "RETURN"
     Case K_logn
          Encode_kdo = "LN"
     Case P_start
          Encode_kdo = "HALT"
     Case K_clearx
          Encode_kdo = "CX"
     Case K_xhochy
          Encode_kdo = "x^y"
     Case K_chgxy
          Encode_kdo = "x<->y"
     Case K_stoplus
          Encode_kdo = "STO+"
     Case K_stominus
          Encode_kdo = "STO-"
     Case K_stomal
          Encode_kdo = "STO*"
     Case K_stodurch
          Encode_kdo = "STO/"
     Case K_pause
          Encode_kdo = "PAUSE"
     Case K_minusx
          Encode_kdo = "/-/"
     Case K_rnd
          Encode_kdo = "RND"
     Case K_einsdrchx
          Encode_kdo = "1/x"
     Case K_fix2
          Encode_kdo = "Fix"
     Case K_roll
          Encode_kdo = "RDN"
     Case K_quadr
          Encode_kdo = "SQR"
     Case P_ifbig
          Encode_kdo = "IF x>0"
     Case P_ifequal
          Encode_kdo = "IF x=0"
     Case P_ifless
          Encode_kdo = "IF x<0"
     Case P_ifxbigy
          Encode_kdo = "IF x>y"
     Case P_ifxequaly
          Encode_kdo = "IF x=y"
     Case P_ifxlessy
          Encode_kdo = "IF x<y"
     Case P_loop7
          Encode_kdo = "Loop 7"
     Case P_loop8
          Encode_kdo = "Loop 8"
     Case P_loop9
          Encode_kdo = "Loop 9"
     Case K_ehochx
          Encode_kdo = "e^X"
     Case P_auto
          Encode_kdo = "RUN"
     Case P_nop
          Encode_kdo = "NOP"
     Case K_pi
          Encode_kdo = "PI"
     Case K_lstx
          Encode_kdo = "LSTx"
     Case K_grd
          Encode_kdo = "grd"
     Case K_int
          Encode_kdo = "INT"
     Case K_frac
          Encode_kdo = "FRAC"
     Case K_abs
          Encode_kdo = "ABS"
     Case K_asin
          Encode_kdo = "ASIN"
     Case K_acos
          Encode_kdo = "ACOS"
     Case K_atan
          Encode_kdo = "ATAN"
     Case K_sinus
          Encode_kdo = "SIN"
     Case K_cosinus
          Encode_kdo = "COS"
     Case K_tangens
          Encode_kdo = "TAN"
     Case K_hex_a
          Encode_kdo = "A"
     Case K_hex_b
          Encode_kdo = "B"
     Case K_hex_c
          Encode_kdo = "C"
     Case K_hex_d
          Encode_kdo = "D"
     Case K_hex_e
          Encode_kdo = "E"
     Case K_hex_f
          Encode_kdo = "F"
   End Select

End Function Encode_kdo



' ========================================================================
' Eingabefunktion von der Tastenmatrix - machen wir was draus
' Tastaturmatrix
' PC4, PC5, PD2-PD7 - Zeilen - Output
' Wir steuern mit einer 0
' PC0-PC3 - Spalten - Input,
' Ueberarbeitete Funktion, die Spalten werden richtig interpretiert
' ========================================================================
Function Inmaxkey() As Byte
   Local L As Byte                                          ' Zeilenzähler laeuft von 0 bis 7
   Local L3 As Byte                                         ' Zeilenzähler laeuft von 0 bis 7
   Local I As Byte
   Local K As Byte                                          ' Eingabe von den Spalten, hier kann eine 0, 1, 2, 4  oder 8 ankommen
   Local K3 As Byte                                         ' Eingabe von den Spalten, hier kann eine 0, 1, 2, 4  oder 8 ankommen

   I = 1                                                    ' Indexbyte, hier schieben wir eine 1 drurch
   Inmaxkey = 0

   For L = 0 To 7
     ' Vorbereitung, wir geben auf eine der Zeilen eine 0
     Portc.4 = 1
     Portc.5 = 1
     Portd = &HFF

     ' 0 -> C4
     If L = 0 Then                                          ' Entweder C4/C5
        Portc.4 = 0
     End If
     ' 1 -> C5
     If L = 1 Then
        Portc.5 = 0
     End If
     ' 2-7, wir nehmen die durch das I-Register geschobene 1
     If L > 1 Then                                          ' oder D2-D7
       Portd = Not I
     End If

     ' K liest die C-Ports aus
     K = Pinc
     ' Einer könnte eine 0 haben, invertieren, damit es eine 1 wird
     K = Not K
     ' Wir brauchen die stellen 0-3
     K = K And &B00001111
     If K > 0 Then                                          ' Wenn ein Knopf gedrueckt wurde
          For L3 = 0 To 3
             K3 = K And &B00000001
             If K3 <> 0 Then
               L = L * 4                                    ' Wenn wir eine Taste haben, brauchen wir auch nicht weitermachen
               Inmaxkey = L + L3
               ' Die Keycodes laufen jetzt von 0-31, um die 0 als NOKEY zu erkennen, machen wir +1
               Incr Inmaxkey
             End If
             Shift K , Right
          Next L3
     End If
     Shift I , Left
   Next L

   ' Die Taste sollte natuerlich entprellt werden
   If Inmaxkey = Lstkey Then
      Inmaxkey = 0
   Else
      Lstkey = Inmaxkey
   End If

End Function Inmaxkey


' ========================================================================
' Wir schreiben nicht direkt in den EEprom, sondern in den Ram
' Bei gelegenheit wird dann der EEprom aktualisiert
' ========================================================================
Sub Update_cache()                                          ' Den Cache in den Eram zurueckschreiben
Local Speicher As Double
Local I1 As Byte

  For I1 = 1 To K_num_mem
     If Fe_mem(i1) = 1 Then
        Ee_mem(i1) = Ce_mem(i1)
        Fe_mem(i1) = 0
     End If
  Next I1
End Sub Update_cache


' -JG-

' ========================================================================
' Den String "Con" für "connect" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_con()
#if Block_communication = 1
      Local I As Byte
      Call Clear_t_st()
      T_st(15) = "U"
      T_st(14) = "S"
      T_st(13) = "B"
      T_st(11) = "-"
      T_st(10) = "-"
      T_st(9) = "-"
      T_st(8) = "-"
#else
      T_st(8) = "C"                                         ' C
      T_st(7) = "o"                                         ' o
      T_st(6) = "n"                                         ' n
#endif
        Call Anzeigen
End Sub Display_con


' ========================================================================
' Den String "Load" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_load()
      Local I As Byte
      Call Clear_t_st()
      T_st(15) = "L"                                        ' L
      T_st(14) = "o"                                        ' O
      T_st(13) = "a"                                        ' A
      T_st(12) = "d"                                        ' d
      Call Anzeigen
End Sub Display_load


' ========================================================================
' Den String "Save" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_save()
      Local I As Byte
      Call Clear_t_st()
      T_st(15) = "S"                                        ' S
      T_st(14) = "a"                                        ' A
      T_st(13) = "v"                                        ' V
      T_st(12) = "e"                                        ' E
      Call Anzeigen
End Sub Display_save

' ========================================================================
' PC empfängt Binärdaten (Programspeicher von Boris) - keine Fehlerbehandlung
' ========================================================================
Sub File_receive()
   Local I As Byte
   Local Zeichen As Word
   Local Code As Byte

   Call Display_save                                        ' Anzeige "Save"
   For I = 1 To K_num_prg                                   ' kompletter Speicherinhalt (510 Byte)
     Zeichen = Ee_program(i)                                ' Lese Word
     Code = High(zeichen)                                   ' High-Teil senden
     Printbin Code
     Code = Low(zeichen)
     Printbin Code                                          ' Low-Teil senden
   Next
End Sub File_receive


' ========================================================================
' PC sendet Binärdaten an Boris, abspeichern im Programspeicher - keine Fehlerbehandlung
' ========================================================================
Sub File_send()
   Local I As Byte                                          ' Counter
   Local Zeichen As Word                                    ' Doppelbyte im EEPROM
   Local Code As Byte
   Dim Buffer(25) As Word                                   ' Zwischenspeicher weil EEPROM schreiben zu langsam

   Call Display_load                                        ' Anzeige "Load"
   For I = 1 To 25                                          ' kompletter Speicherinhalt (512 Byte)
    Do
    Loop Until Ucsr0a.rxc0 = 1                              ' warten bis nächste Zeichen empfangen (immer High - Low)
    Code = Udr                                              ' High-Teil
    Zeichen = Code * 256
    Do
    Loop Until Ucsr0a.rxc0 = 1                              ' warten bis nächste Zeichen empfangen
    Code = Udr                                              ' Low-Teil
    Zeichen = Zeichen + Code
    Buffer(i) = Zeichen                                     ' Zwischenspeichern
   Next

   For I = 1 To K_num_prg
    Ee_program(i) = Buffer(i)                               ' von Buffer nach EEPROM umkopieren
   Next

   Print "ready"                                            ' UART Ausgabe
End Sub File_send



#if Block_communication = 1

' ========================================================================
' Protokolliges Empfangen von einem Datenblock mit Pruefsumme und Quittung
' Wir bekommen ein Paket von 12 Binär-Bytes
'
'   // Byte 0: Blocknummer, zaehlt hoch
'   // Byte 1: Verwendung
'   //          01 - Info-Block, wird nicht gespeichert
'   //          02 - Programmblock
'   // Byte 2-9 Datenbytes
'   // Byte 10 Niederes Byte der Summe über 0-9
'   // Byte 11 Folgekennzeichen
'   //          0x0F - Es folgt ein weiterer Datenblock
'   //          0xFF - Dateiende

'
' Headerblock:
'   // Byte 0: Blocknummer, = 0
'   // Byte 1: Verwendung   = 01
'   //          01 - Info-Block, wird nicht gespeichert
'   // Byte 2 Startadresse des Programme im Speicher
'   // Byte 3-9 Label zur Anzeige im Display o.ae
'   // Byte 10 Niederes Byte der Summe über 0-9
'   // Byte 11 Folgekennzeichen = 0x0F
'
' Wenn der Block sauber angekommen ist, Quittieren wir mit 2 Bytes
'   0x58 - Pruefsumme stimmt, alles OK - sonst 0x59 - Fehler
'   xx   - Blocknummer des gelesenen Blocks oder FF
'
' ========================================================================

Sub Upload_block()
   Local Summe As Byte
   Local I As Byte
   Local J As Byte
   Local Flag As Byte

   Local Zch As Word                                        ' Doppelbyte im EEPROM
   Local Newchar As Byte

   G_uart_error = 0
   Summe = 0                                                ' Fehlerspeicher loeschen
   Flag = 0

   ' Wir lesen 12 Zeichen in den Lesepuffer Zbuffer
   For J = 1 To 12
      I = 0
      Do
         Waitms 10
         Flag = Ischarwaiting()
         Incr I
      Loop Until Flag = 1 Or I > 100
      If Flag = 1 Then
        Inputbin Newchar , 1
        ' Newchar = Udr
        Zbuffer(j) = Newchar
      Else
        G_uart_error = J
      End If
   Next J

   If G_uart_error = 0 Then
      For I = 1 To 10
         Summe = Summe + Zbuffer(i)
      Next I
   End If

   If Summe = Zbuffer(11) And F_nextblock = Zbuffer(1) Then
      ' Sauber gelesen! Wenn es  der Block 0 war, wissen wir jetzt einige Steuerdaten
      F_blocknr = Zbuffer(1)
      F_blockuse = Zbuffer(2)
      F_blockfolg = Zbuffer(12)

      If F_blocknr = 0 Then                                 ' Startadresse lesen und merken
         F_blockptr = Zbuffer(3) + 1                        ' Wir bekommen die logische Startadresse 0, brauchen aber den Index 1, sonst fehlt der erste Befehl
      End If
                                                         ' Alles OK, wir schreiben den EEPROM
      If F_blocknr = &HFF Then                              ' Abbruchbedingung, es gibt keinen Block mit BN FF
         G_uart_error = &HFF                                ' Keine Ahnung, ob wir das noch nutzen wollen
         F_blockfolg = &HFF                                 ' nicht weiterlesen!
         Printbin &H59 ;
         Printbin &HFF ;
         Exit Sub
      End If
                                                         ' Alles OK, wir schreiben den EEPROM
      If F_blockuse = 2 Then
         J = 3
         For I = 1 To 4
            Zch = Zbuffer(j) * 256
            Incr J
            Zch = Zch + Zbuffer(j)
            Incr J
            Ee_program(f_blockptr) = Zch                    ' von Buffer nach EEPROM umkopieren
            Incr F_blockptr
         Next I
      End If
      ' Wir erwarten den naechsten Block
      F_nextblock = F_blocknr + 1
      ' Quittung senden
      Printbin &H58 ;
      Print Chr(f_blocknr) ;
   Else
      ' Fehler!
      Printbin &H59 ;
      Printbin &HFF ;
   End If

End Sub Upload_block


' Eine ganze Datenuebertragung mit mehreren Bloecken
' Faengt immer mit Block 0 an
' Daraus lesen wir die Startadresse
' Es wird so lange gelesen, bis ein Endblock erkannt wird
' Jeder Block wird quittiert
Sub Upload_file()
   T_st(8) = D_char_pfr                                     ' Pfeil rechts
   Call Anzeigen

   ' Als erstes soll der Headerblock kommen
   F_nextblock = 0
   Do
      Call Upload_block()
      T_st(6) = To_digit(f_blocknr \ 10)
      T_st(5) = To_digit(f_blocknr Mod 10)
      Call Anzeigen
   Loop Until F_blockfolg = &HFF

End Sub Upload_file


' Protokolliges Senden einer Datei
Sub Download_file()

  T_st(11) = D_char_pfl                                     ' Pfeil links
  Call Anzeigen

  Local Indx As Word
  Local Zch As Word
  Local Programsize As Byte
  Local Bi As Byte
  Local Bj As Byte

  Local Bpc As Byte                                         ' Der Programmzeiger , physisch 1-255

  ' Bestimmen wir erst mal, wie gross die zu sichernde Datei ist
  ' Wir suchen den Programmspeicher rueckwaerts nach Sinn ab

  Indx = K_num_prg

  Do
     Zch = Ee_program(indx)
     If Zch = &HFFFF Then Zch = K_nop
     Decr Indx
  Loop Until Zch <> K_nop And Indx > 0

  If Indx > 0 Then                                          ' Wir haben etwas sinnvolles gefunden
     Programsize = Indx + 1
     F_blocknr = 0
     Call Download_headerblock(programsize)

     If G_uart_error = 0 Then
        ' Und jetzt die Datenbloecke
        Bpc = 1
        Do
           Waitms 100

           Incr F_blocknr
           Zbuffer(1) = F_blocknr
           Zbuffer(2) = 2
           Bj = 3

           For Bi = 1 To 4
              Zch = Ee_program(bpc)                         ' Lese Word
              Zbuffer(bj) = High(zch)                       ' High-Teil senden
              Incr Bj
              Zbuffer(bj) = Low(zch)
              Incr Bj
              Incr Bpc
           Next Bi
           If Bpc >= Programsize Then
              Call Download_block(&Hff)
           Else
              Call Download_block(&H0f)
           End If
           If G_uart_error <> 0 Then
              ' Fehler, abbruch!
              Bpc = To_digit(g_uart_error)
              Call Display_error(bpc)
              Bpc = &HFF
           End If
           T_st(6) = To_digit(f_blocknr \ 10)
           T_st(5) = To_digit(f_blocknr Mod 10)
           Call Anzeigen
        Loop Until Bpc >= Programsize Or G_uart_error <> 0
     End If
   End If
End Sub Download_file


' Headerblock: In die Schnittstelle schreiben
'   // Byte 0: Blocknummer, = 0
'   // Byte 1: Verwendung   = 01
'   //          01 - Info-Block, wird nicht gespeichert
'   // Byte 2 Startadresse des Programme im Speicher
'   // Byte 3 Programmgroesse
'   // Byte 4 Boris-Version
'   // Byte 10 Niederes Byte der Summe über 0-9
'   // Byte 11 Folgekennzeichen = 0x0F
Sub Download_headerblock(byval Size As Byte)

  Local Indx As Word

        Zbuffer(1) = 0
        Zbuffer(2) = 1
        Zbuffer(3) = 0
        Zbuffer(4) = Size
        Zbuffer(5) = 5
        For Indx = 6 To 10
           Zbuffer(indx) = &H21
        Next Indx

        Call Download_block(&H0f)
End Sub Download_headerblock


' Protokolliges Senden von einem Datenblockes mit Pruefsumme und Quittung
' Die Daten sind bereits im Zbuffer vorbereitet
' Der Protokollstatus ist
'   G_uart_error = 0   - Alles OK
'   G_uart_error <> 0  - Fehler
Sub Download_block(byval Schluss As Byte)
  Local Ptr As Byte
  Local Zchn As Byte
  Local Si As Byte
  Local A1 As Byte
  Local A2 As Byte
  Local Qflag As Byte

  ' Pruefsumme und Folge /schlussbyte
  Si = 0
  For Ptr = 1 To 10
      Si = Si + Zbuffer(ptr)
  Next Ptr

  Zbuffer(11) = Si
  Zbuffer(12) = Schluss

  ' Zeichenweise auf die UART ausgeben
  For Ptr = 1 To 12
      Zchn = Zbuffer(ptr)
      Print Chr(zchn) ;
  Next Ptr

  ' Auf die Quittung warten
  Si = 100                                                  ' Maximal 1 Sekunde auf Quittung warten
  Do
     Waitms 10
     Qflag = Ischarwaiting()
     Incr Si
  Loop Until Qflag = 1 Or Si < 1

  If Qflag = 1 Then
      Inputbin A1 , 1
      Inputbin A2 , 1
      ' If A1 = &H58 And A2 = Zbuffer(1) Then
      If A1 = &H58 Then
         G_uart_error = 0
      Else
         G_uart_error = Si
      End If
  End If

End Sub Download_block

' Remote-Start eines Programms ueber die serielle Schnittstelle
' Wir empfangen nur den Header-Block
' Dort steht die Verwendung 03 und die Startadresse
Sub Run_program()

  T_st(11) = D_char_pfr                                     ' Pfeil rechts
  T_st(8) = D_char_pfl                                      ' Pfeil links
  Call Anzeigen

  ' Wir lesen nur den Headerblock
  F_nextblock = 0
  Call Upload_block()

  If Zbuffer(2) = 3 Then
     P_pc = Zbuffer(3)                                      ' Der PC ist logisch (0-254)
     P_goflag = 1
  End If
End Sub Run_program


#endif

' ========================================================================
' UART-Funktion zum Senden und Empfangen von Zeichen über die UART
' ========================================================================
Sub Uart()
   Local Zeichen As Byte
   Local Zeichenflag As Byte

   Disable Timer0                                           ' Timer Interrupts sperren
   Call Save_w_st                                           ' Anzeigeregister retten

   Zeichen = Inkey()                                        ' Ein Zeichen von der UART

   If Zeichen = Uart_sync Then                              ' UART Sychronzeichen erkannt
    Print K_version                                         ' Antworten mit Versionsnummer
    Call Display_con                                        ' "connect" auf der Anzeige darstellen

#if Block_communication = 1
    Do
      Waitms 10
      Zeichenflag = Ischarwaiting()
    Loop Until Zeichenflag = 1                              ' warten bis nächste Zeichen empfangen (immer High - Low)
    Zeichen = Inkey()                                       ' High-Teil
#else
    Do
    Loop Until Ucsr0a.rxc0 = 1                              ' wartenn bis nächste Zeichen empfangen
    Zeichen = Udr                                           ' Zeichen aus dem UART-Puffer lesen
#endif

    Select Case Zeichen                                     ' Auswertung des Kommandos
     Case &H53 : Call File_send                             ' sendet Programspeicher zum PC (Binärdaten)
     Case &H52 : Call File_receive                          ' empfängt Binärdaten vom PC für Programspeicher
#if Block_communication = 1
     Case &H54 : Call Upload_file                           ' Blockweise routine PC -> boris
     Case &H55 : Call Download_file                         ' Blockweise Routine boris -> PC
     Case &H56 : Call Run_program                           ' Blockweise Routine RUN
#endif
    End Select
   End If
   Call Restore_w_st                                        ' Anzeigeregister wieder herstellen
   Call Display_status_line()
   Call Anzeigen
   Enable Timer0                                            ' Timer  Interrupts wieder zulassen
End Sub Uart

' ========================================================================
' EOF
' ========================================================================
