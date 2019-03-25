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
'  "Wissenschaftliche" Variante mit U821-Siebensegmentcode
'  V2 - Programmierbar
'
'  100 Programmschritte (00-99) im EEPROM
'  10 Zahlenspeicher (0-9) im EEPROM
'  16 Unterprogrammebenen mit GOSUB und RETURN
'
'  Updates: 2.0 Initialversion, basiert auf der V1.11
'               Tastaturbelegung bereinigt, Anzeige des Programmspeichers
'           2.2 Neue Polling Routine, Speichern und Editieren von Programmcode
'           2.3 Programmausführung
'           2.4 Cleanup, Busy-Anzeige bei Programmausführung
'           2.5 Refactoring Tastenentprellung, Error-Funktion
'           2.6 Anzeige im Run-Modus verbessert, NOP-behandlung,
'           2.7 Caching der Zahlenspeicher (EEPROM), Fehler bei Adressbehandlung korrigiert
'           2.8 Fehler beim Cx im Zifferneingabemodus korrigiert, Turbo-Run
'           2.9 Schlafmodus nur, wenn wir nicht auf die Eingabe nach dem "F" warten,
'           2.10 Beepme beim Enter korrigiert, Codebereinigung, Ueberarbeiteter Display-Modus
'           2.11 Compile-Switch um zwischen U821 und normaler Zifferndarstellung zu unterscheiden
'           2.12 Busy-Anzeige bei Programmausfuehrung
'           2.13 Nochmal die Enter- und Rolldown Funktion korrigiert (HP29C-Kompatibilitaet)
'           2.14 (JG) UART Funktion zum Sichern und Laden von Programmen eingeführt
'           2.15 Einstellungsmimik (Displaymodus, grd/rad) geaendert, rechnende Speicher
'           2.16 Dezimalpunktfehler bei Mehrfacheingabe
'
'
'----------------------------------------------------------

$regfile = "m328pdef.dat"                                   ' ATmega328-Deklarationen

$prog &HFF , &H62 , &HD9 , &HFF                             ' generated. Take care that the chip supports all fuse bytes.
$crystal = 1000000                                          ' Kein Quarz: 1MHz MHz
$baud = 9600                                                ' Baudrate der UART: 9600 Baud

$hwstack = 196                                              ' hardware stack (32)
$swstack = 196                                              ' SW stack (10)
$framesize = 256                                            ' frame space (40)

$lib "single.lbx"
$lib "double.lbx"
$lib "fp_trig.lbx"

' Hardware/Softwareversion
Const K_version = "4.2.16"                                  '

' Compile-Switch um zwischen U821 und normaler Zifferndarstellung zu unterscheiden
Const U821_disp = 1                                         ' U821 Display Mode
' Const U821_disp = 0                                        ' "normaler" Display Mode

' Compile-Switch um HP29C-kompatibel zu sein, beim Runterrutschen nach dem Rechnen, wird der Inhalt von Rt erhalten
Const Hp29c_comp = 1
' Const Hp29c_comp = 0 ' Rt wird mit "0" initialisiert


' Tastaturmatrix
' PB0-PB6 - Zeilen - Output
' Wir steuern mit einer 0
' unbenutzte Pins mit pullup auf 5v

Ddrb = &B01111111
Portb = &B11111111

' PC0-PC3 - Spalten - Input

Ddrc = &B00000000
Portc = &B11111111

' -JG-
' UART-Funktion
Const Uart_sync = &HAA                                      ' Synchron-Byte

' Grunddefinitionen
' Die Anzeige kann was? - Noch umzusetzen
Const S_max_digit = 8                                       ' Wiviel Anzeigestellen hat das Display
Const S_disp_float = 0                                      ' Displaymodus Float
Const S_disp_fix2 = 1                                       ' Displaymodus FIX2
Const S_disp_eng = 2                                        ' Displaymodus "E"
Const S_disp_hm = 3                                         ' Displaymodus H:M

' ========================================================================
' Funktions- und Subroutine Deklarationen
' ========================================================================
Declare Sub Polling()                                       ' Interrupt-Routine, Tastaturabfrege und Eingabeinterpretation

Declare Function Inmaxkey() As Byte                         ' Tastaturmatrix abfragen
Declare Function Key2kdo(incode As Byte) As Byte            ' Key decodieren
Declare Function Convert(incode As Byte) As Byte            ' Zahl 2 7Segment
Declare Function Digit_input(inputkey As Byte) As Byte      ' Unterscheiden Ziffer oder Kommando
Declare Function Needs_adress(inputkey As Byte) As Byte     ' Wieviel Adressziffern braucht das Kommando?
Declare Function Is_transparent(inputkey As Byte) As Byte   ' Transparente Kommandos werden nicht gespeichert, sondern auch im Edit-Mode gleich ausgefuehrt

' Anzeigefunktionen
Declare Sub Init_max7219()                                  ' Initialisierung der Anzeige, Helligkeit, Modus u.s.w.
Declare Sub Anzeigen()                                      ' Schleife ueber das Anzeigefeld, Umwandlung in 7segmentcode
Declare Sub Interpr_rx()                                    ' Die Anzeigefunktion, wir interpretieren Rx in das W_st Register
Declare Sub Show_version()                                  ' Anzeige der Programmversion in in das W_st Register
Declare Sub Dosleep()                                       ' Ruhezustand erster Ordnung * /
Declare Sub Wakeme()                                        ' Aufwecken aus dem Ruhezustand erster Ordnung * /
Declare Sub Beepme()                                        ' Ein kurzes Blinzeln mit der Anzeige
Declare Sub Save_w_st()                                     ' Anzeigeregister W_st sichern
Declare Sub Restore_w_st()                                  ' Anzeigeregister W_st zurueckladen
Declare Sub Clear_output()                                  ' Ausgaberegister leeren
Declare Sub Error_string(byval Ec As Byte)                  ' Die Error-Zeichenkette ausgeben
Declare Sub Show_f_key()                                    ' Anzeige: Der F-Key ist aktiv

Declare Function Round_me(byval Dbl_in As Double , Num As Byte) As Double       ' Runden fuer die Anzeige
Declare Sub Disp_e_float(byval Dbl_in As Double)            ' Grosse Float-Anzeige mit "E"


' Eingabefunktionen
Declare Sub Translate_x()                                   ' uebersetzen wir das Eingaberegister nach x
Declare Sub Clear_input()                                   ' Eingaberegister leeren
Declare Sub Input_number()                                  ' Zahleneingabe ins Eingaberegister
Declare Sub Input_to_rx()                                   ' Den Inhalt von Trans_input nach Rx bringen
Declare Sub Clean_dp_in_input(byval Position As Byte)       ' Alle ggf. schon eingegeben Dezimalpunkte bereinigen

Declare Sub Dimmme()                                        ' Displayhelligkeit umschalten

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

' 3. Speicher fuer die LED-Anzeige
Dim I_st(16) As Byte                                        ' Eingabe-Register
Dim W_st(8) As Byte                                         ' Das Anzeige-Register
Dim S_st(8) As Byte                                         ' Eine Kopie des Anzeige-Registers
Dim Display_adress As Byte , Display_daten As Byte          ' Arbeitszellen fuer Display
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

Dim Trans_input As Double                                   ' Umgewandelte Zahl aus dem Eingabestring
Dim Bcheck As Byte
Dim Errx As Byte
Dim Inv_key As Bit                                          ' Flag, jemand hat die Zweitbelegung der Tasten angefordert

Dim Rnd_setup As Bit                                        ' Flag, der Zufallszahlengenerator ist initialisiert
Dim ___rseed As Word                                        ' Der Startwert des Zufallszahlengenerators
Dim Intrnd As Word                                          ' Int Ergebnis des Zufallszahlengenerators

' 5. Permanentspeicher
Dim Ce_mem(10) As Double                                    ' Cache fuer den Zahlenspeicher
Dim Fe_mem(10) As Byte                                      ' Flags, ob eine Speicherzelle geschrieben worden ist
Dim Ee_mem(10) As Eram Double                               ' Die persistente Variante des Zahlenspeichers

Dim Ee_fixflag As Eram Byte                                 ' Wir haben jetzt auch einen Festkomma-Modus mit 2 Nachkommastellen
Dim Ee_displ As Eram Byte                                   ' Einstellung fuer Displayhelligkeit
Dim Ee_grdrad As Double                                     ' Umrechnungsfaktor Radiant / grd fuer Winkelfunktionen

' 6. Konstanten
Dim Pi_k As Double

' 7. Für die Programmierung brauchen wir natürlich noch mehr
Dim Ee_program(100) As Eram Word                            ' Das Programm steht im EEPROM, 100 Speicherzellen 1 Byte code, 1 Byte Adresse
Dim Ee_program_valid As Eram Byte                           ' Der Inhalt des EEPROM koennte etwas sinnvolles sein
Dim P_stack(16) As Byte                                     ' Für die Returns bei GOSUB
Dim P_sp As Byte                                            ' Stackpointer, eigentlich ein Index
Dim P_pc As Byte                                            ' Der Programmzeiger, Logisch, 0-99
Dim P_runflag As Bit                                        ' Flag ob wir gerade im Auto- oder Programmiermodus sind
Dim P_goflag As Bit                                         ' Flag ob wir gerade das Programm ausfuehren oder interaktiv rechnen

Dim P_heartbeat As Byte                                     ' Flag Zur Schlangensteuerung


' ========================================================================
' Kommandocodes
' 48-57 sind Ziffern
' Ab der 65 entstehen sie durch Aufaddieren von K_F_OFFSET = 64
' Obergrenze: 127

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

Const K_f_offset = 64                                       ' Offset fuer die Zweitbelegung

Const K_dimm = K_plus + K_f_offset                          ' 65   - Dimmen der Anzeige
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
Const K_ehochx = K_logn + K_f_offset                        ' 77   - e hoch x
Const P_auto = P_start + K_f_offset                         ' 78   - Umschaltung Run / Program
Const P_nop = K_clearx + K_f_offset                         ' 79  - No Operation    "cx"
Const K_pi = K_xhochy + K_f_offset                          ' 80  - Pi    "über x hoch y"
Const K_lstx = K_chgxy + K_f_offset                         ' 81   - Lstx,

Const K_grd = 48 + K_f_offset                               ' 112  - grd / rad toggle   "0"
Const K_int = 49 + K_f_offset                               ' 113  - INT   "1"
Const K_frac = 50 + K_f_offset                              ' 114  - FRAC  "2"
Const K_abs = 51 + K_f_offset                               ' 115  - ABS   "3"
Const K_asin = 52 + K_f_offset                              ' 116  - ARCUS SINUS   "4"
Const K_acos = 53 + K_f_offset                              ' 117  - ARCUS COSINUS   "5"
Const K_atan = 54 + K_f_offset                              ' 118  - ARCUS TANGENS   "6"
Const K_sinus = 55 + K_f_offset                             ' 119  - SINUS   "7"
Const K_cosinus = 56 + K_f_offset                           ' 120  - COSINUS   "8"
Const K_tangens = 57 + K_f_offset                           ' 121  - TANGENS   "9"

Const K_zweit = 128                                         '

Const K_dp_disp = 128                                       '

' Zeichencodes
Const D_minus = 10
Const D_char_ul = 11
Const D_space = 13
Const D_char_grd = 14

Const D_char_a = 20
Const D_char_e = 21
Const D_char_r = 22
Const D_char_o = 23
Const D_char_h = 24
Const D_char_c = 25
Const D_char_p = 26
Const D_char_n = 27
Const D_char_s = 28
' -JG-
Const D_char_d = 29
Const D_char_bc = 30
Const D_char_bl = 31
Const D_char_bs = 32
Const D_char_bu = 33


' ========================================================================

' ========================================================================
' Hauptprogramm
' ========================================================================

' ========================================================================
' Initialisierung
' ========================================================================

' Das SPI-Interface zur 7-Segmentanzeige
Config Portd.3 = Output : Din_display Alias Portd.3
Config Portd.5 = Output : Clk_display Alias Portd.5
Config Portd.2 = Output : Cs_display Alias Portd.2

' Initialisieren der UPN-Rechenregister
Rx = 0.0
Ry = 0.0
Rz = 0.0
Rt = 0.0
Lstx = 0.0

' Initialisieren der Flags und Hilfsvariablen
Lstkey = 0
Sleepflag = 0
Inv_key = 0
Rnd_setup = 0
Z_inputflag = 0
Store_kdo_active = 0

Pi_k = 3.141592653589793238462643383279502

' Die EEPROM-Inhalte koennten nach dem Brennen Unsinn enthalten
If Ee_fixflag <> 1 And Ee_fixflag <> 2 And Ee_fixflag <> 3 Then Ee_fixflag = 0

If Ee_program_valid <> 1 Then
  Ee_program_valid = 1
  ' DIe Programmspeicher muessen zurueckgesetzt werden
  ' 0 = NOP
  For Index = 1 To 100
     Ee_program(index) = K_nop
  Next Index
End If


' Die Permanentspeicher muessen in den Cache gelesen werden, dabei werden sie u.U. gleich initialisiert
For Index = 1 To 10
' 5. Permanentspeicher
  Rx = Ee_mem(index)
  Bcheck = Checkfloat(rx)
  Errx = Bcheck And 5
  If Errx > 0 Then Rx = 0.0                                 ' Initialisierung bei Lesen vor dem Schreiben
  Ce_mem(index) = Rx
  Fe_mem(index) = 0                                         ' Unveraendert-Flag
Next Index

Rx = 0.0

If Ee_displ <> &H01 Then Ee_displ = &H08

Bcheck = Checkfloat(ee_grdrad)
Errx = Bcheck And 5
If Errx > 0 Then Ee_grdrad = Pi_k / 180.0                   ' Beim Einschalten verwenden wir grd
If Ee_grdrad = 0.0 Then Ee_grdrad = Pi_k / 180.0            ' Falls noch undefiniert verwenden wir grd

' Für den Programmiermodus muessen auch ein paar Variablen initialisiert werden

P_stack(1) = 0                                              ' Beim Einschalten geht es bei 0 los
P_sp = 1
P_pc = 0                                                    ' Beim Einschalten geht es bei 0 los
P_runflag = 0                                               ' 0 =  Auto, 1 = Programmiermodus
P_goflag = 0                                                ' Beim EInschalten sind wir im Interaktiv-Modus

P_heartbeat = 0

' Jetzt den Timer einstellen,
On Timer0 Polling                                           'Interrupt-Routine für Timer0-Overflow
Config Timer0 = Timer , Prescale = 1024                     'Timer-Takt ist Quarz/1024
' Rechnen wir mal, wir haben 1k Ticks pro sekunde,
' Vorteiler 1024 ergibt 1024 Interrupts pro Sekunde
' wenn wir 40 mal in der Sekunde pollen wollen, wäre der Timer auf 256-25 zu setzen

Timer0 = 231

Enable Timer0
Enable Interrupts

' Ausgaberegister leeren und Display initialisieren
Call Clear_output
' Call Interpr_rx
Call Clear_input                                            ' Eingaberegister leeren
Call Show_version
Call Init_max7219
Call Anzeigen

Waitms 1000

Call Interpr_rx
Call Anzeigen

Do                                                          'Hauptschleife
      Waitms 1000

      ' -JG-
      If Ucsr0a.rxc0 = 1 Then Call Uart                     ' Zeichen auf der UART-Schnittstelle empfangen
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

  Pc = P_pc + 1

  Tmatrix = Inmaxkey()                                      ' Abfrage der Tastaturmatrix, Return Tastenposition
  Pressedkey = Key2kdo(tmatrix)                             ' Umwandeln in einen Tastaturcode

  If P_goflag = 1 Then                                      ' Wenn ein Programm ausgeführt wird

      If Pressedkey <> 0 Then                               ' Jeder Tastendruck stoppt das laufende Programm
         P_goflag = 0
         Call Interpr_rx
         Call Anzeigen
         Goto Weiter
      End If

      Store_kdo_active = 0

      Code_word = Ee_program(pc)

      X_kommando = High(code_word)                          ' Trennung Code von Adresse
      X_adresse = Low(code_word)

      Saved_ppc = P_pc                                      ' Zur Erkennung, ob ein GOTO ausgefuehrt wurde

      Is_ziffer = Digit_input(x_kommando)

      If Is_ziffer = 1 Then                                 ' Eine Ziffer wurde Im Programmspeicher gelesen
         Pressedkey = X_kommando
         Call Input_number()
      Else
         Retval = Exec_kdo()
         If Retval <> 0 Then Goto Weiter
      End If

      If Saved_ppc = P_pc Then Incr P_pc
      If P_pc > 99 Then                                     ' Bei Ueberlauf Fehlermeldung
        Call Error_string(d_char_p)
        Goto Weiter
      End If

      Call Interpr_rx

      Call Anzeigen
      Sleepflag = 0

  Else                                                      ' Interaktiv

      If Pressedkey > 0 And Sleepflag > 1200 Then           ' Ein Knopf im Schlafmodus gedrueckt
          Pressedkey = 0
          Sleepflag = 0
          Call Wakeme
          Goto Weiter
      End If

      If Pressedkey = 0 Then Goto Nokey

      If Pressedkey = K_zweit Then                          ' F (= Zweitbelegung) wurde gerade gedrueckt
         Inv_key = Not Inv_key                              ' Toggle
         Call Show_f_key()                                  ' Anzeige umschalten auf Punkte
         Call Anzeigen
      End If

      If Pressedkey = K_zweit Then Goto Weiter

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
      '                   * Speicheraktionen haben eine einstellige Adresse (0-9)
      '                     und zwischen Kdo und Adresse ggf. eine Operation + - * /
      '                   * Sprungbefehle haben eine zweistellige Adresse (00-99)

      Is_ziffer = Digit_input(pressedkey)

      If Is_ziffer = 1 Then                                 ' Eine Ziffer wurde gedrueckt, das kann adresse oder Eingabe sein
         If Adr_input_flag = 0 Then                         ' Wir brauchen keine Adresse zum letzten Kommando
             X_adresse = 0
             Call Input_number()
         Else                                               ' Adresseingabe
             If Pressedkey <> K_point Then                  ' Der Punkt wird bei der Eingabe einer Adresse einfach ignoriert
                X_adresse = X_adresse * 10
                X_adresse = X_adresse + Pressedkey
                X_adresse = X_adresse - 48                  ' Der  Keycode der Zahlen  ist ASCII
                Decr Adr_input_flag
                If Adr_input_flag = 0 Then Is_ziffer = 0    ' Wenn die Adresse Komplett ist, betrachten wir die Eingabe als ein Kommando
             End If
         End If
         Store_kdo_active = 0
      Else                                                  ' Keine Ziffer sondern ein Kommando

         If Pressedkey = K_store Then                       ' STORE, es koennte sein, dass wir ein "Zwischenkommando" fuer den rechnenden Speicher brauchenRechnende Speicher brauchen noch eine Eingabe
            Store_kdo_active = 1
         End If

         ' Die Rechenenden Speicher, Wir berechnen deas neue Kommando
         If Pressedkey >= K_plus And Pressedkey <= K_durch Then
            If Store_kdo_active = 1 Then
               Pressedkey = K_rechn_speicher + Pressedkey
               Store_kdo_active = 0
            End If
         End If

         Adr_input_flag = Needs_adress(pressedkey)          ' Die naechsten x ziffern gehen in die Adressfelder

         If Adr_input_flag <> 0 Then
             Call Beepme
         End If

         X_adresse = 0
         X_kommando = Pressedkey                            ' Umwandeln Byte -> Word

      End If

      If Adr_input_flag <> 0 Then Goto Weiter               ' Noch gehen Adresseingaben ab

      Transp_kdo = Is_transparent(pressedkey)               ' Manche Kommandos muessen auch im Programmiermodus ausgefuehrt werden

      ' SO, hier ist jetzt alles aufbereitet.
      ' Jetzt muss nur noch:
      '   a) der Prozessor gerufen werden mit X_kommando und X_adresse
      '   oder b) der schmuseputz in den Programmspeicher geschrieben werden. In diesem Fall muss die Ziffer natürlich dazu

      If P_runflag = 0 Or Transp_kdo = 1 Then               ' 0 =  Auto, 1 = Programmiermodus
         If Is_ziffer = 0 Then                              ' Die letzte Eingabe war ein Kommando
            Retval = Exec_kdo()
            If Retval <> 0 Then Goto Weiter
         End If
      Else                                                  ' Programmiermodus
         If Is_ziffer = 0 Then
            If X_kommando = P_nop Then X_kommando = K_nop   ' Wir versuchen, die NOPs im Speicher als 00 stehen zu haben
            ' Die Eingabe soll in den Programmspeicher
            ' Index = P_pc + 1                             ' Unsere Speicherzellen beginnen bei 0, BASCOM bei 1
            Code_word = X_kommando * 256                    ' Platz lassen fuer den Adressteil
            Code_word = Code_word + X_adresse               '
         Else                                               ' Auch ziffern sollen in den Programmspeicher
            Code_word = Pressedkey * 256                    ' Das Adressfeld brauchen wir bei Ziffern nicht
         End If

         Ee_program(pc) = Code_word

         Disable Interrupts
         Call Interpr_rx
         Call Anzeigen
         Waitms 700
         Incr P_pc
         If P_pc > 99 Then P_pc = 99                        ' Hier rollen wir mal nicht ueber
         Enable Interrupts
         Call Interpr_rx
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
           Call Dosleep
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
  Else
     Timer0 = 231                                           '256-25
  End If
End Sub Polling


' ========================================================================
' War die eingabe eine Ziffer oder ein Kommando?
' ========================================================================
Function Digit_input(inputkey As Byte) As Byte
   Digit_input = 0
   If Inputkey > 47 And Inputkey < 58 Then Digit_input = 1
   If Inputkey = K_point Then Digit_input = 1               ' Der Dezimalpunkt
End Function Digit_input


' ========================================================================
' Wieviel Adressziffern braucht das Kommando?
' ========================================================================
Function Needs_adress(inputkey As Byte) As Byte
   Needs_adress = 0                                         ' Normalerweise brauchen wir keine Adresse
   Select Case Inputkey

      ' Zahlenspeicher
      Case K_store
        Needs_adress = 1
      Case K_recall
        Needs_adress = 1

      ' Rechnende Speicher
      Case K_stoplus
        Needs_adress = 1
      Case K_stominus
        Needs_adress = 1
      Case K_stomal
        Needs_adress = 1
      Case K_stodurch
        Needs_adress = 1

      ' Sprungbefehle
      Case P_goto
        Needs_adress = 2
      Case P_gosub
        Needs_adress = 2
      Case P_ifless
        Needs_adress = 2
      Case P_ifequal
        Needs_adress = 2
      Case P_ifbig
        Needs_adress = 2

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
' Eingaberegister leeren
' ========================================================================
Sub Clear_input()
   Local N As Byte
   For N = 1 To 16
      I_st(n) = " "
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
   For N = 1 To 8
      W_st(n) = D_space
      ' S_st(n) = D_Space
   Next N
   ' W_st(8) = 0
   ' S_st(8) = 0
End Sub Clear_output


' ========================================================================
' Anzeige: F-Taste gedrueckt
' ========================================================================
Sub Show_f_key()
    If Inv_key = 1 Then                                     ' gerade gedrueckt, Anzeige umschalten auf Punkte
          ' Ziffer_in = W_st(8)                               ' clear_output schreibt eine 0 in die 8.Anzeigestelle, wir merken uns, was da stand
          Call Save_w_st
          Call Clear_output
          W_st(8) = D_space + K_dp_disp
          ' S_st(8) = Ziffer_in
          If Ee_grdrad = 1.0 Then                           ' Winkelfunktionen in Bogenmass , der 5. oder 4. Dezimalpunkt leuchtet
            W_st(4) = D_space + K_dp_disp                   ' Leerzeichen + Dezimalpunkt
          Else
            W_st(5) = D_space + K_dp_disp
          End If
     Else
          Call Restore_w_st
     End If
End Sub Show_f_key

' ========================================================================
' Zahleneingabe ins Eingaberegister
' ========================================================================
Sub Input_number()
Local N_3 As Byte
    Z_inputflag = 1
    If I_pt = 2 And I_st(1) = 0 And Pressedkey > K_point Then I_pt = 1       ' "0"-Verriegelung d.h 00 am Anfang ist unsinn
    If I_pt < 9 Then
       If Pressedkey = K_point Then
          Call Clean_dp_in_input(i_pt)
          If I_pt = 1 Then
             I_st(1) = K_dp_disp
             Incr I_pt
          Else
             I_st(i_pt -1) = I_st(i_pt -1) + K_dp_disp
          End If
       Else
          I_st(i_pt) = Pressedkey - 48
          Incr I_pt
       End If
    End If
    ' waehrend der Eingabe geben wir das Eingaberegister selbst aus, aber nur wenn im Run-Mode
    If P_runflag = 0 Then
       For N_3 = 1 To I_pt
           W_st(9 -n_3) = I_st(n_3)
       Next N_3
       For N_3 = I_pt To 8
           W_st(9 -n_3) = D_space
       Next N_3
    Else
       Call Beepme
    End If
End Sub Input_number


' ========================================================================
' Es kann nur einen Punkt in der Eingabe geben!
' ========================================================================
Sub Clean_dp_in_input(byval Position As Byte)               ' Alle ggf. schon eingegeben Dezimalpunkte bereinigen
    Local Lp As Byte
    For Lp = 1 To Position
       If I_st(lp) >= K_dp_disp Then
          I_st(lp) = I_st(lp) - K_dp_disp
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
End Sub Input_to_rx


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


    Exec_kdo = 0                                            ' Default: OK

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
      Case K_dimm                                           ' Dimmen der Anzeige
         Call Dimmme
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
      Case K_fix2                                           ' Umschalten Anzeigemodus Float -> Fix2 -> -> Eng -> H:M ...
         If X_adresse > 3 Then X_adresse = 0
         Ee_fixflag = X_adresse
         Call Beepme
      Case K_roll                                           ' Roll Down
         Lstx = Rx
         Rx = Ry
         Ry = Rz
         Rz = Rt
         Rt = Lstx
      Case K_store                                          ' STO
         If L_adr > 0 And L_adr < 11 Then
            Ce_mem(l_adr) = Rx
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Error_string(d_char_a)
            Exec_kdo = 1
         End If
         Call Beepme
      ' Rechnende Speicher
      Case K_stoplus                                        ' STO +
         If L_adr > 0 And L_adr < 11 Then
            Memcont = Ce_mem(l_adr) + Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Error_string(d_char_a)
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stominus                                       ' STO -
         If L_adr > 0 And L_adr < 11 Then
            Memcont = Ce_mem(l_adr) - Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Error_string(d_char_a)
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stomal                                         ' STO *
         If L_adr > 0 And L_adr < 11 Then
            Memcont = Ce_mem(l_adr) * Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Error_string(d_char_a)
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_stodurch                                       ' STO /
         If L_adr > 0 And L_adr < 11 Then
            Memcont = Ce_mem(l_adr) / Rx
            Ce_mem(l_adr) = Memcont
            Fe_mem(l_adr) = 1                               ' Cache als modifiziert markieren
         Else
            Call Error_string(d_char_a)
            Exec_kdo = 1
         End If
         Call Beepme
      Case K_recall                                         ' RCL
         If L_adr > 0 And L_adr < 11 Then
            Call Enter
            Rx = Ce_mem(l_adr)
         Else
            Call Error_string(d_char_a)
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
         Rx = Rx * Ee_grdrad
         Rx = Sin(rx)                                       '
      Case K_asin                                           ' ArcusSinus
         Lstx = Rx
         Rx = Asin(rx)                                      '
         Rx = Rx / Ee_grdrad
      Case K_cosinus                                        ' COS
         Lstx = Rx
         Rx = Rx * Ee_grdrad
         Rx = Cos(rx)                                       '
      Case K_acos                                           ' ArcusCosinus
         Lstx = Rx
         Rx = Acos(rx)                                      '
         Rx = Rx / Ee_grdrad
      Case K_tangens                                        ' TAN
         Lstx = Rx
         Rx = Rx * Ee_grdrad
         Rx = Tan(rx)                                       '
      Case K_atan                                           ' ArcusTangens
         Lstx = Rx
         Rx = Atn(rx)                                       '
         Rx = Rx / Ee_grdrad
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
            Ee_grdrad = Pi_k / 180.0                        ' Winkelfunktionen in Grad
         Else                                               ' rad
            Ee_grdrad = 1.0                                 ' Winkelfunktionen in Bogenmass
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
           P_runflag = Not P_runflag
      Case P_back                                           ' Ein Schritt rueckwaerts im Programmspeicher
           If P_pc = 0 Then P_pc = 100
           If P_pc > 0 Then Decr P_pc
      Case P_vor                                            ' Ein Schritt vorwarets im Programmspeicher
           Incr P_pc
           If P_pc > 99 Then P_pc = 0                       ' Wir rollen einfach über
      Case P_goto                                           ' Den Programmzeiger auf die Adresse stellen
           P_pc = X_adresse
           Call Beepme
      Case P_gosub
           If P_sp < 16 Then
              Incr P_sp                                     '
              P_stack(p_sp) = P_pc
              P_pc = X_adresse
           Else
              Call Error_string(d_char_s)
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
              Call Error_string(d_char_s)
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
      Case P_start                                          ' Start / Stop der Programmausfuehrung
           P_goflag = Not P_goflag
           If P_goflag = 1 Then
              Pc = P_pc + 1
              L_code = Ee_program(pc)
              L_cmd = High(l_code)                          ' Trennung Code von Adresse
              If L_cmd = P_start Then                       ' Ein P_start waehrend des Laufes bedeutet: Erst mal halt, aber dann mglw. weiter, also p_pc incrementieren
                 Incr P_pc
                 Call Interpr_rx
                 Exec_kdo = 1                               ' Ein wenig wie Error, wenn wir dann im Polling weitermachen direkt zum weiter
              Else
                 P_sp = 1                                   ' Stackpointer zurücksetzen bei Programmstart
              End If
           End If
           Call Beepme
      Case K_nop
           Call Beepme
      Case P_nop                                            ' tu nix, im Programmspeicher ist da eine 0 oder 255 besser
           Call Beepme
      End Select

No_execution:
    X_kommando = 0
    X_adresse = &HFF

Finish_kdo:
    ' Das Kommando koennte den Inhalt von "Rx" geändert haben, wir uebertragen den Inhalt in die Anzeige
    Call Interpr_rx

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
' Die Anzeigefunktion, wir interpretieren Rx in das W_st Register
' Im Programmiermodus wird der zum PC gehörige Programmspeicher angezeigt
' ========================================================================
Sub Interpr_rx()

  Local Ii As Byte
  Local Ij As Byte
  Local Rxs1 As String * 32
  Local Snumber As Byte
  Local Posc As String * 1
  Local Posn As Byte

  Local Fixi As Double
  Local Fixint As Long
  Local Fixdiff As Long
  Local Fixfrac As Double

  Local Rxwrk As Double

  Local Hmstunden As Long
  Local Hmminuten As Long

  Local Pcode_wrk As Byte

  Local Fixcode As Word

  Local Code_word As Word
  Local Pcode As Byte
  Local Adress As Byte

  Local Snake As Byte

  ' Anzeige leer machen
  For Ii = 1 To 8
     W_st(ii) = D_space
  Next Ii

  If P_goflag = 0 Then                                      ' Anzeige nur, wenn wir nicht gerade ein Programm lauren lassen

      If P_runflag = 0 Then                                 ' interaktiver Auto-modus
         Bcheck = Checkfloat(rx)
         Errx = Bcheck And 5

         ' Im Fix-Modus haben wir einen kleineren Anzeigebereich
         ' -99999.99 <= Rx <= 999999.99
         If Ee_fixflag = S_disp_fix2 Then
            If Rx <= -100000.0 Then Incr Errx
            If Rx >= 1000000.0 Then Incr Errx
         End If

         ' Im H:M-Modus haben wir einen kleineren Anzeigebereich
         ' -999.99 <= Rx <= 9999.99
         If Ee_fixflag = S_disp_hm Then
            If Rx <= -1000.0 Then Incr Errx
            If Rx >= 10000.0 Then Incr Errx
         End If

         ' Wenn kein Error - Ausgeben
         If Errx = 0 Then

            Rxwrk = Abs(rx)                                 ' Das Vorzeichen machen wir dann selbst

            If Ee_fixflag = S_disp_fix2 Then                ' Fix2 -Anzeige

               Rxwrk = 100.0 * Rxwrk                        ' Zwei Feste Nachkommastellen
               Fixi = Int(rxwrk)
               Fixint = Fixi
               Fixfrac = Rxwrk - Fixi
               If Fixfrac > 0.5 Then Incr Fixint            ' Einfache Rundungsregel
               For Ii = 1 To 8
                   Fixdiff = Fixint Mod 10
                   W_st(ii) = Fixdiff
                   Fixint = Fixint \ 10
                   If Fixint = 0 And Ii > 2 Then
                     Ii = 8
                   End If
               Next Ii
               W_st(3) = W_st(3) + K_dp_disp
               If Rx < 0.0 Then W_st(8) = D_minus

            End If

            If Ee_fixflag = S_disp_float Then               ' Float-Anzeige


              If Rx < 0.0 Then
                 Ij = 7                                     ' Die Position, wo die Ziffern in der Anzeige beginnen
              Else
                 Ij = 8
              End If

              If Rxwrk < 10000000.0 And Rxwrk > 0.00001 Then       ' Kleine Float-Anzeige ohne E

                 Rxwrk = Round_me(rxwrk , Ij)

                 Fixi = Int(rxwrk)
                 Fixint = Fixi                              ' Cast auf Integer
                 Fixfrac = Rxwrk - Fixi
                 ' Fixdiff = Fixfrac                             ' Cast auf integer

                 If Fixint > 0 Then                         ' Die Zahl ist groesser als 1
                    ' Aufarbeiten der Vorkommastellen
                    Rxs1 = Str(fixint)
                    Snumber = Len(rxs1)

                    Snumber = Ij - Snumber                  ' Die Einerstelle
                    Incr Snumber

                    For Ii = Snumber To Ij
                       Fixdiff = Fixint Mod 10
                       W_st(ii) = Fixdiff
                       Fixint = Fixint \ 10
                    Next Ii
                    W_st(snumber) = W_st(snumber) + K_dp_disp       ' Den Dezimalpunkt
                    Ij = Snumber - 1
                 Else
                    W_st(ij) = 0
                    W_st(ij) = W_st(ij) + K_dp_disp         ' Das ist erst mal die "0."
                    Decr Ij
                 End If

                 While Ij > 0 And Fixfrac > 0.0             ' Es sind noch stellen in der Anzeige verfügbar
                     Fixfrac = Fixfrac * 10.0
                     Fixi = Int(fixfrac)
                     Fixint = Fixi
                     W_st(ij) = Fixint
                     Fixfrac = Fixfrac - Fixi
                     Decr Ij
                 Wend
              Else                                          ' Grosse Float-Anzeige mit "E"
                  Call Disp_e_float(rxwrk)
              End If
              If Rx < 0.0 Then W_st(8) = D_minus
              If Rx = 0.0 Then W_st(8) = 0 + K_dp_disp      ' Das ist erst mal die "0."
            End If

            If Ee_fixflag = S_disp_eng Then                 ' Float-Anzeige mit "E"
              Call Disp_e_float(rxwrk)
              If Rx < 0.0 Then W_st(8) = D_minus
              If Rx = 0.0 Then W_st(8) = 0 + K_dp_disp      ' Das ist erst mal die "0."
            End If

            If Ee_fixflag = S_disp_hm Then                  ' H:M - Anzeige
               ' Der Wert im Rx sind Stunden mit komma, rechnen wir erst mal in Minuten um:
               Rxwrk = Rxwrk * 60.0                         ' Minuten
               Fixi = Int(rxwrk)
               Fixint = Fixi
               Fixfrac = Rxwrk - Fixi
               If Fixfrac > 0.5 Then Incr Fixint            ' Einfache Rundungsregel

               ' Minuten und Stunden wie gewohnt
               Hmstunden = Fixint \ 60
               Hmminuten = Fixint Mod 60

               ' Und nun die Anzeige
               W_st(1) = Hmminuten Mod 10
               W_st(2) = Hmminuten \ 10

               For Ii = 3 To 6
                   Fixdiff = Hmstunden Mod 10
                   W_st(ii) = Fixdiff
                   Hmstunden = Hmstunden \ 10
                   If Hmstunden = 0 And Ii > 3 Then
                     Ii = 8
                   End If
               Next Ii
               W_st(3) = W_st(3) + K_dp_disp
               If Rx < 0.0 Then W_st(7) = D_minus
               W_st(8) = 24                                 ' ein "h" an der ersten Stelle
            End If
         Else                                               ' Zeichenkette "Error" Ausgeben
           Call Error_string(d_space)
         End If
      Else                                                  ' Programmiermodus, die zum PC gehoerige Programmzeile wird angezeigt
         If P_pc > 99 Then P_pc = 0                         ' Wir rollen einfach über
         ' If P_pc < 0 Then P_pc = 99                            ' Wir rollen einfach über
         Index = P_pc + 1                                   ' Unsere Speicherzellen beginnen bei 0, BASCOM bei 1
         Code_word = Ee_program(index)

         Pcode = High(code_word)                            ' Trennung Code von Adresse

         ' Und nun die Anzeige
         W_st(8) = P_pc \ 10
         W_st(7) = P_pc Mod 10
         W_st(6) = D_space
         W_st(3) = Pcode Mod 10
         Pcode_wrk = Pcode \ 10
         W_st(4) = Pcode_wrk Mod 10
         W_st(5) = Pcode_wrk \ 10
         Adress == Needs_adress(pcode)
         If Adress > 0 Then
             Adress = Low(code_word)
             W_st(3) = W_st(3) + K_dp_disp
             W_st(2) = Adress \ 10
             W_st(1) = Adress Mod 10
         Else
             W_st(2) = D_space
             W_st(1) = D_space
         End If
      End If
  Else
      ' Busy - Anzeige bei der Programmabarbeitung
      Incr P_heartbeat
      If P_heartbeat > 63 Then P_heartbeat = 0
      Snake = P_heartbeat \ 8                               ' Snake = 0-7
      Incr Snake                                            ' 1-8
      W_st(snake) = D_space
      Incr Snake
      If Snake > 8 Then Snake = 1
      W_st(snake) = D_space + K_dp_disp
  End If

End Sub Interpr_rx




' ========================================================================
' Anzeige im Eng-Modus (mit "E")
' ========================================================================
Sub Disp_e_float(byval Dbl_in As Double)                    ' Grosse Float-Anzeige mit "E"

  Local Iii As Byte
  Local Ijj As Byte
  Local Rxs2 As String * 32
  Local Strindex As Byte
  Local Posc As String * 1
  Local Posn As Byte


  Rxs2 = Str(dbl_in)
  Strindex = Len(rxs2)

  If Rx < 0.0 Then
             Ijj = 7
  Else
             Ijj = 8
  End If

  For Iii = 1 To Strindex
      Posc = Mid(rxs2 , Iii , 1)
      Select Case Posc
          Case "-" :
               Posn = D_minus
          Case "E" :
               Posn = D_char_e
               Ijj = Strindex - Iii                         ' 4
               Incr Ijj
          Case "." :
               Incr Ijj
               Posn = W_st(ijj) + K_dp_disp
          Case "0" To "9" :
               Posn = Val(posc)
      End Select

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





' ========================================================================
' Den String "Error" in die Anzeige schreiben
' Ec = Errorcode zum Anzeigen
' ========================================================================
Sub Error_string(byval Ec As Byte)

        W_st(8) = D_space
        W_st(7) = D_char_e
        W_st(6) = D_char_r
        W_st(5) = D_char_r
        W_st(4) = D_char_o
        W_st(3) = D_char_r
        W_st(2) = D_space
        W_st(1) = Ec

        P_goflag = 0                                        ' Fehler fuehren immer zum Programmhalt
        Call Anzeigen

End Sub Error_string

' ========================================================================
' Eine weitere Anzeigefunktion, wir interpretieren den Versionsstring in das W_st Register
' Der Versionsstring hat bis zu 7 Zeichen und besteht aus Ziffern und Punkten
' Const K_version = "4.1.11"                                  '
' ========================================================================
Sub Show_version()

  Local Vsrx As String * 32
  Local Vii As Byte
  Local Vij As Byte
  Local Vposc As String * 1
  Local Vposn As Byte
  Local Vinputlen As Byte

  Vsrx = K_version

  W_st(8) = D_char_c                                        ' c
  Vij = 5

  ' Call Filldisplaystring(srx , Ij)

  Vinputlen = Len(vsrx)

  For Vii = 1 To Vinputlen
         Vposc = Mid(vsrx , Vii , 1)
         Select Case Vposc
                Case "-" :
                   Vposn = D_minus
                Case "E" :
                   Vposn = D_char_e
                   Vij = Vinputlen - Vii                    ' 4
                   Vij = Vij + 1
                   ' W_st(2) = 15
                   ' W_st(1) = 15
                Case "." :
                   Vij = Vij + 1
                   Vposn = W_st(vij) + K_dp_disp
                Case "0" To "9" :
                   Vposn = Val(vposc)
         End Select

         If Vij > 0 Then
               W_st(vij) = Vposn
               Vij = Vij - 1
         End If
  Next Vii

End Sub Show_version



' ========================================================================
' uebersetzen wir das Eingaberegister nach x
' ========================================================================
Sub Translate_x()
   Local Stelle As Double
   Local Below_one As Double
   Local Decflag As Byte
   Local N_1 As Byte                                        ' Index im Eingabefeld
   Local Punkt As Byte

   Trans_input = 0.0                                        ' Hier bauen wir die Zahl auf
   Below_one = 0.0
   Decflag = 0                                              ' Ein Dezimalpunkt wurde erkannt, es folgen Nachkommastellen

   For N_1 = 1 To I_pt -1
        Stelle = I_st(n_1)
        Punkt = 0
        If Stelle > 127 Then                                ' Diese Stelle hat einen Dezimalpunkt (128.0)
           Stelle = Stelle - K_dp_disp
           Punkt = 1
        End If
        If Decflag = 0 Then                                 ' Normale Ziffern vor dem Komma
           Trans_input = Trans_input * 10
           Trans_input = Trans_input + Stelle
        Else                                                ' Nachkommastellen
           Below_one = Below_one / 10.0
           Stelle = Stelle * Below_one
           Trans_input = Trans_input + Stelle
        End If
        If Punkt = 1 Then                                   ' Diese Stelle hatte einen Dezimalpunkt
           Below_one = 1.0
           Decflag = 1
        End If
   Next N_1
End Sub Translate_x


' ========================================================================
' Decodieren des Keycodes zu Ziffern und Kommandos
' Die Codierung ist ziemlich haemdsaermlich, die Ziffern haben ihren ASCII-Code,
' Die Kommandos zaehlen einfach hoch, "F" macht dann noch mal K_F_OFFSET drauf (in der Polling-Routine)
' ========================================================================
Function Key2kdo(incode As Byte) As Byte
   Key2kdo = 0                                              ' Default, nokey
   Select Case Incode
     Case 2
       Key2kdo = "0"                                        ' 48
     Case 9
       Key2kdo = "1"                                        ' 49
     Case 10
       Key2kdo = "2"                                        ' 50
     Case 12
       Key2kdo = "3"                                        ' 51
     Case 17
       Key2kdo = "4"                                        ' 52
     Case 18
       Key2kdo = "5"                                        ' 53
     Case 20
       Key2kdo = "6"                                        ' 54
     Case 25
       Key2kdo = "7"                                        ' 55
     Case 26
       Key2kdo = "8"                                        ' 56
     Case 28
       Key2kdo = "9"                                        ' 57

     Case 1
       Key2kdo = K_point                                    ' "."
     Case 56
       Key2kdo = K_enter                                    ' "Enter"

     Case 8
       Key2kdo = K_plus                                     ' "+"
     Case 16
       Key2kdo = K_minus                                    ' "-"
     Case 24
       Key2kdo = K_mal                                      ' "*"
     Case 32
       Key2kdo = K_durch                                    ' "/"

     Case 41
       Key2kdo = K_zweit                                    ' "F" - Zweitbelegung der Tasten

     Case 42
       Key2kdo = K_store                                    ' STO
     Case 44
       Key2kdo = K_recall                                   ' RCL
     Case 50
       Key2kdo = K_sqrt                                     ' SQRT
     Case 33
       Key2kdo = P_goto                                     ' GOTO
     Case 34
       Key2kdo = P_gosub                                    ' GOSUB
     Case 36
       Key2kdo = P_return                                   ' RETURN
     Case 40
       Key2kdo = K_logn                                     ' LN
     Case 48
       Key2kdo = P_start                                    ' START / STOP
     Case 4
       Key2kdo = K_clearx                                   ' CX
     Case 49
       Key2kdo = K_xhochy                                   ' x hoch y
     Case 52
       Key2kdo = K_chgxy                                    ' x <-> y

   End Select
End Function Key2kdo


' ========================================================================
' Eingabefunktion von der Tastenmatrix - machen wir was draus
' ========================================================================
Function Inmaxkey() As Byte
   Local L As Byte                                          ' Zeilenzähler laeuft von 0 bis 6
   Local I As Byte
   Local K As Byte                                          ' Eingabe von den Spalten, hier kann eine 0, 1, 2, 4  oder 8 ankommen

   I = 1                                                    ' Indexbyte, hier schieben wir eine 1 drurch
   Inmaxkey = 0

   For L = 0 To 6
       Portb = Not I
       K = Pinc
       K = Not K
       K = K And &B00001111
       If K > 0 Then
          L = L * 8                                         ' Wenn wir eine Taste haben, brauchen wir auch nicht weitermachen
          Inmaxkey = K + L
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
' Wandelt eine Ziffer in den Siebensegmentcode um
' Fuer 0, 6, 9 haben wir die "kleineren" Darstellungen des U821D
' ========================================================================
Function Convert(incode As Byte) As Byte
   Local Komma As Byte
   Komma = 0
   Convert = 0

   If Incode >= K_dp_disp Then
      Komma = 1
      Incode = Incode - K_dp_disp
   End If

   Select Case Incode
     Case 0
#if U821_disp = 0
       Convert = 126                                        ' big zero
#else
       Convert = 29                                         ' short zero
#endif
     Case 1
       Convert = 48
     Case 2
       Convert = 109
     Case 3
       Convert = 121
     Case 4
       Convert = 51
     Case 5
       Convert = 91
     Case 6
#if U821_disp = 0
       Convert = 95                                         ' big six
#else
       Convert = 31                                         ' short six
#endif
     Case 7
       Convert = 112
     Case 8
       Convert = 127
     Case 9
#if U821_disp = 0
       Convert = 123                                        ' big nine
#else
       Convert = 115                                        ' short nine
#endif
     Case D_minus                                           ' - Minus
       Convert = 1
     Case D_char_ul                                         ' _ Underline
       Convert = 8
     Case D_space                                           ' Leerzeichen
       Convert = 0
     Case D_char_grd                                        ' °
       Convert = 99
     Case D_char_a                                          ' A
       Convert = 119
     Case D_char_e                                          ' E
       Convert = 79
     Case D_char_r                                          ' r
       Convert = 5
     Case D_char_o                                          ' o
       Convert = 29
     Case D_char_h                                          ' h
       Convert = 23
     Case D_char_c                                          ' c
       Convert = 13
     Case D_char_p                                          ' P
       Convert = 103
     Case D_char_n                                          ' n
       Convert = 21
     Case D_char_s                                          ' S
       Convert = 91
' JG-
     Case D_char_bc                                         ' C
       Convert = 78
     Case D_char_bl                                         ' L
       Convert = 14
     Case D_char_d                                          ' d
       Convert = 61
     Case D_char_bu                                         ' U
       Convert = 62
   End Select

   If Komma = 1 Then
      Convert = Convert + K_dp_disp
      Incode = Incode + K_dp_disp
   End If

End Function Convert

' ========================================================================
' Der Stromsparmodus, die Anzeige braucht bis zu 100mA
' Wenn lange nichts passiert, schalten wir die Anzeige ab
' ========================================================================

' ========================================================================
' Ausgaberegister Retten
' ========================================================================
Sub Save_w_st()
   Local N As Byte
   For N = 1 To 8
      S_st(n) = W_st(n)
   Next N
End Sub Save_w_st

' ========================================================================
' Stromsparmodus einschalten
' ========================================================================
Sub Dosleep()                                               ' Nachtruhe
   ' Ausgaberegister Retten und leeren
   Local N As Byte
   Call Save_w_st
   For N = 1 To 8
      W_st(n) = D_space
   Next N
   W_st(1) = W_st(1) + K_dp_disp                            ' Ein Dezimalpunkt nur
   Call Anzeigen
End Sub Dosleep

' ========================================================================
' Ausgaberegister Rekonstruieren
' ========================================================================
Sub Restore_w_st()
   Local N As Byte
   For N = 1 To 8
      W_st(n) = S_st(n)
   Next N
End Sub Restore_w_st

' ========================================================================
' Ausgaberegister Rekonstruieren und wieder anzeigen
' ========================================================================
Sub Wakeme()
   Call Restore_w_st
   Call Anzeigen
End Sub Wakeme

' ========================================================================
' Kurzes Blinzeln mit der Anzeige um unsichtbare Kommandos bemerkbar zu machen
' ========================================================================
Sub Beepme()
   If P_goflag = 0 Then                                     ' Nur im Interaktiven Modus
      Disable Interrupts
      Call Dosleep
      Waitms 100
      Call Wakeme
      Enable Interrupts
   End If
End Sub Beepme


' ========================================================================
' Displayhelligkeit umschalten
' ========================================================================
Sub Dimmme()                                                ' Displayhelligkeit umschalten
   ' Ee_displ enthaelt den Wert fuer die Helligkeit
   If Ee_displ = &H08 Then Ee_displ = &H01 Else Ee_displ = &H08       ' Wir togglen bei jedem Aufruf
   Display_adress = &H0A : Display_daten = Ee_displ         ' Intensity auf gespeicherten Wert (1 oder 8) setzen
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
End Sub Dimmme


' ========================================================================
' Wir schreiben nicht direkt in den EEprom, sondern in den Ram
' Bei gelegenheit wird dann der EEprom aktualisiert
' ========================================================================
Sub Update_cache()                                          ' Den Cache in den Eram zurueckschreiben
Local Speicher As Double
Local I1 As Byte

  For I1 = 1 To 10
     If Fe_mem(i1) = 1 Then
        Ee_mem(i1) = Ce_mem(i1)
        Fe_mem(i1) = 0
     End If
  Next I1
End Sub Update_cache


' ========================================================================
' Schleife ueber das Anzeigefeld, Umwandlung in 7segmentcode
' Input ist nicht Rx, sondern das Anzeigeregister w_st
' ========================================================================
Sub Anzeigen()
   Local Disp7code As Byte
   Local N_1 As Byte
   Local N_2 As Byte
   For N_1 = 1 To 8
      N_2 = 9 - N_1                                         ' Durch einen Loetfehler ist der Index hier andersherum
      ' N_2 = N_1                                             ' Auf dem Steckbrett haben wir den Fehler nicht
      Disp7code = Convert(w_st(n_2))
      Display_adress = N_1 : Display_daten = Disp7code
      Cs_display = 0
      Shiftout Din_display , Clk_display , Display_adress , 1
      Shiftout Din_display , Clk_display , Display_daten , 1
      Cs_display = 1
   Next N_1
End Sub Anzeigen

' ========================================================================
' Initialisierung der Anzeige, Helligkeit, Modus u.s.w.
' ========================================================================
Sub Init_max7219()
   Display_adress = &H0C : Display_daten = &H00             ' Display = AUS (shutdown mode)
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
   ' Display_adress = &H09 : Display_daten = &HFF             ' Alle Stellen BCD dekodieren
   Display_adress = &H09 : Display_daten = &H00             ' Keine Stellen BCD dekodieren
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
   ' Display_adress = &H0A : Display_daten = &H08             ' Intensity auf 17/32
   Display_adress = &H0A : Display_daten = Ee_displ         ' Intensity auf den Wert aus dem EEprom
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
   Display_adress = &H0B : Display_daten = 7                ' alle Zeichen anzeigen
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
   Display_adress = &H0F : Display_daten = 0                ' Kein Display Test
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
   Display_adress = &H0C : Display_daten = 1                ' Display einschalten
   Cs_display = 0
   Shiftout Din_display , Clk_display , Display_adress , 1
   Shiftout Din_display , Clk_display , Display_daten , 1
   Cs_display = 1
End Sub Init_max7219


' -JG-

' ========================================================================
' Den String "Con" für "connect" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_con()
        W_st(8) = D_char_bc                                 ' C
        W_st(7) = D_char_o                                  ' o
        W_st(6) = D_char_n                                  ' n
        Call Anzeigen
End Sub Display_con


' ========================================================================
' Den String "Load" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_load()
        W_st(8) = D_char_bl                                 ' L
        W_st(7) = 0                                         ' O
        W_st(6) = D_char_a                                  ' A
        W_st(5) = D_char_d                                  ' d
        Call Anzeigen
End Sub Display_load


' ========================================================================
' Den String "Save" in die Anzeige schreiben
' Conect
' ========================================================================
Sub Display_save()
        W_st(8) = D_char_s                                  ' S
        W_st(7) = D_char_a                                  ' A
        W_st(6) = D_char_bu                                 ' U
        W_st(5) = D_char_e                                  ' E
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
   For I = 1 To 100                                         ' kompletter Speicherinhalt (200 Byte)
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
   Dim Buffer(100) As Word                                  ' Zwischenspeicher weil EEPROM schreiben zu langsam

   Call Display_load                                        ' Anzeige "Load"
   For I = 1 To 100                                         ' kompletter Speicherinhalt (200 Byte)
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

   For I = 1 To 100
    Ee_program(i) = Buffer(i)                               ' von Buffer nach EEPROM umkopieren
   Next

   Print "ready"                                            ' UART Ausgabe
End Sub File_send


' ========================================================================
' UART-Funktion zum Senden und Empfangen von Zeichen über die UART
' ========================================================================
Sub Uart()
   Local Zeichen As Byte

   Disable Interrupts                                       ' alle Interrupts sperren
   Call Save_w_st                                           ' Anzeigeregister retten
   Zeichen = Udr                                            ' Zeichen aus dem UART-Puffer lesen
   If Zeichen = Uart_sync Then                              ' UART Sychronzeichen erkannt
    Print K_version                                         ' Antworten mit Versionsnummer
    Call Display_con                                        ' "connect" auf der Anzeige darstellen
    Do
    Loop Until Ucsr0a.rxc0 = 1                              ' wartenn bis nächste Zeichen empfangen
    Zeichen = Udr                                           ' Zeichen aus dem UART-Puffer lesen
    Select Case Zeichen                                     ' Auswertung des Kommandos
     Case &H53 : Call File_send                             ' sendet Programspeicher zum PC (Binärdaten)
     Case &H52 : Call File_receive                          ' empfängt Binärdaten vom PC für Programspeicher
    End Select
   End If
   Call Restore_w_st                                        ' Anzeigeregister wieder herstellen
   Call Anzeigen
   Enable Interrupts                                        ' Interrupts wieder zulassen
End Sub Uart

' ========================================================================
' EOF
' ========================================================================
