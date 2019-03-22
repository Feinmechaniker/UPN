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
'
'  Updates: 1.4 Anzeige des Zustandes bei shift
'           Rechenmodus H:M -> Eingabe und Ausgabe in Stunden und Minuten, Umrechnung bei Switch
'           1.5 Korrektur des Verdrahtungsfehlers beim Prototypen
'           1.6 Dimmen des Displays in 2 Stufen, Kleine Fixes (F-Key-handling), RND Als Zweitbelegung von *
'           1.7 Code Cleanup
'           1.8 Bugfix Eingabe Nachkommastellen
'           1.9 Bugfix Anzeigefehler negative Zahlen im Float-Modus, Umrechnungskonstanten als Zweitbelegung
'           1.11 Code Cleanup, Dokumentation, GPL-Text, Zusammengefasste Displaymodus-steuerung, Versionsstring
'           1.12 Cx-Behandlung im Zifferneingabemodus korrigiert
'           1.13 Schlafmodus nur, wenn wir nicht auf die Eingabe nach dem "F" warten,
'                C_all loescht die Permanentspeicher auch
'           1.14 Beepme beim Enter korrigiert, Codebereinigung, Ueberarbeiteter Display-Modus
'           1.15 Compile-Switch um zwischen U821 und normaler Zifferndarstellung zu unterscheiden
'           1.16 Nochmal die Enter- und Rolldown Funktion korrigiert (HP29C-Kompatibilitaet)
'
'----------------------------------------------------------

$regfile = "m328pdef.dat"                                   ' ATmega328-Deklarationen

$prog &HFF , &H62 , &HD9 , &HFF                             ' generated. Take care that the chip supports all fuse bytes.
$crystal = 1000000                                          ' Kein Quarz: 1MHz MHz
$baud = 9600                                                ' Baudrate der UART: 9600 Baud

$hwstack = 96                                               ' default use 32 for the hardware stack
$swstack = 120                                              ' default use 10 for the SW stack
$framesize = 120                                            ' default use 40 for the frame space

$lib "single.lbx"
$lib "double.lbx"
$lib "fp_trig.lbx"

' Hardware/Softwareversion
Const K_version = "4.1.16"                                  '

' Compile-Switch um zwischen U821 und normaler Zifferndarstellung zu unterscheiden
Const U821_disp = 1                                         ' U821 Display Mode
' Const U821_disp = 0                                         ' "normaler" Display Mode

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
Declare Sub Polling()                                       ' Callback für Polling der Tastatur, wird vom Timer gerufen

Declare Function Inmaxkey() As Byte                         ' Tastaturmatrix abfragen
Declare Function Key2kdo(incode As Byte) As Byte            ' Key decodieren
Declare Function Convert(incode As Byte) As Byte            ' Zahl 2 7Segment
Declare Function Digit_input(inputkey As Byte) As Byte      ' Unterscheiden Ziffer oder Kommando

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

Declare Function Round_me(byval Dbl_in As Double , Num As Byte) As Double       ' Runden fuer die Anzeige
Declare Sub Disp_e_float(byval Dbl_in As Double)            ' Grosse Float-Anzeige mit "E"


' Eingabefunktionen
Declare Sub Input_number()                                  ' Eine Ziffer wurde gedrueckt, wir vervollstaendigen das Eingaberegister I_st
Declare Sub Translate_x()                                   ' uebersetzen wir das Eingaberegister nach x
Declare Sub Clear_input()                                   ' Eingaberegister leeren

Declare Sub Dimmme()                                        ' Displayhelligkeit umschalten

' Bearbeitungsfunktionen
Declare Sub Exec_kdo()                                      ' Hier wird gerechnet
Declare Sub Enter()                                         ' Enter -funktion Der Rechenregister * /
Declare Sub Rolldown()                                      ' Rolldown -funktion Der Rechenregister * /


' ========================================================================
' Nun denn: Variablen
' ========================================================================

' 1. Flags
Dim Z_inputflag As Bit                                      ' Es wurde vor dem Kommand bereits mindestens eine Ziffer eingegeben
Dim Memoryflag As Byte                                      ' Vorbereitung einer Speicheraktion, 0 = inaktiv, 1 = STO, 2 = RCL, es filgt die Speicheradresse
Dim Sleepflag As Integer
' Dim Save_fixflag As Byte


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

Dim Trans_input As Double                                   ' Umgewandelte Zahl aus dem Eingabestring
Dim Bcheck As Byte
Dim Errx As Byte

Dim Inv_key As Bit                                          ' Flag, jemand hat die Zweitbelegung der Tasten angefordert

Dim Rnd_setup As Bit                                        ' Flag, der Zufallszahlengenerator ist initialisiert
Dim ___rseed As Word                                        ' Der Startwert des Zufallszahlengenerators
Dim Intrnd As Word                                          ' Int Ergebnis des Zufallszahlengenerators

' 5. Permanentspeicher
Dim Ee_mem(10) As Eram Double
Dim Ee_fixflag As Eram Byte                                 ' Wir haben jetzt auch einen Festkomma-Modus mit 2 Nachkommastellen
Dim Ee_displ As Eram Byte                                   ' Einstellung fuer Displayhelligkeit
Dim Ee_grdrad As Double                                     ' Umrechnungsfaktor Radiant / grd fuer Winkelfunktionen

' 6. Konstanten
Dim Pi_k As Double


' ========================================================================
' Kommandocodes
' 48-57 sind Ziffern
' Ab der 65 entstehen sie durch Aufaddieren von K_F_OFFSET = 64
' Obergrenze: 127

Const K_plus = 1                                            ' "+"
Const K_minus = 2                                           ' "-"
Const K_mal = 3                                             ' "*"
Const K_durch = 4                                           ' "/"
Const K_point = 5                                           ' "."
Const K_enter = 6                                           ' "Enter"
Const K_store = 7                                           ' STO
Const K_recall = 8                                          ' RCL
Const K_sqrt = 9                                            ' SQRT
Const K_sinus = 10                                          ' SIN
Const K_cosinus = 11                                        ' COS
Const K_tangens = 12                                        ' TAN
Const K_logn = 13                                           ' LN
Const K_log10 = 14                                          ' LOG
Const K_clearx = 15                                         ' CX
Const K_xhochy = 16                                         ' x hoch y
Const K_chgxy = 17                                          ' x <-> y

Const K_f_offset = 64                                       ' Offset fuer die Zweitbelegung

Const K_dimm = K_plus + K_f_offset                          ' 65   - Dimmen der Anzeige
Const K_minusx = K_minus + K_f_offset                       ' 66   - 0.0 - x
Const K_rnd = K_mal + K_f_offset                            ' 67   - RND
Const K_einsdrchx = K_durch + K_f_offset                    ' 68   - 1/x
Const K_fix2 = K_point + K_f_offset                         ' 69   - Umschalten Eng -> Fix2 -> H:M
Const K_roll = K_enter + K_f_offset                         ' 70   - Roll Down
Const K_quadr = K_sqrt + K_f_offset                         ' 73   - Quadrat
Const K_asin = K_sinus + K_f_offset                         ' 74   - ArcusSinus
Const K_acos = K_cosinus + K_f_offset                       ' 75   - ArcusCosinus
Const K_atan = K_tangens + K_f_offset                       ' 76   - ArcusTangens
Const K_ehochx = K_logn + K_f_offset                        ' 77   - e hoch x
Const K_10hochx = K_log10 + K_f_offset                      ' 78   - 10 hoch x
Const K_creg = K_clearx + K_f_offset                        ' 79   - C all
Const K_lstx = K_chgxy + K_f_offset                         ' 81   - Lstx,
' Const K_hmin = 48 + K_f_offset                              ' 112  - H:M   "0"
Const K_grd = 49 + K_f_offset                               ' 113  - grd   "1"
Const K_rad = 50 + K_f_offset                               ' 114  - rad   "2"
Const K_pi = 51 + K_f_offset                                ' 115  - Pi    "3"
Const K_int = 52 + K_f_offset                               ' 116  - INT   "4"
Const K_frac = 53 + K_f_offset                              ' 117  - FRAC  "5"
Const K_abs = 54 + K_f_offset                               ' 118  - ABS   "6"
Const K_minft = 55 + K_f_offset                             ' 119  - m/ft   "7"
Const K_kminmil = 56 + K_f_offset                           ' 120  - km/mile   "8"
Const K_mminzoll = 57 + K_f_offset                          ' 121  - mm/inch   "9"


Const K_zweit = 128                                         '

Const K_dp_disp = 128                                       '

' Symbolische Zeichencodes
Const D_minus = 10
Const D_char_ul = 11
Const D_space = 13

Const D_char_e = 21
Const D_char_r = 22
Const D_char_o = 23
Const D_char_h = 24
Const D_char_c = 25
Const D_char_grd = 14



' ========================================================================

' ========================================================================
' Hauptprogramm
' ========================================================================

' ========================================================================
' Initialisierung
' ========================================================================

' Jetzt den Timer einstellen,
On Timer0 Polling                                           'Interrupt-Routine für Timer0-Overflow
Config Timer0 = Timer , Prescale = 1024                     'Timer-Takt ist Quarz/1024
' Rechnen wir mal, wir haben 1k Ticks pro sekunde,
' Vorteiler 1024 ergibt 1024 Interrupts pro Sekunde
' wenn wir 40 mal in der Sekunde pollen wollen, wäre der Timer auf 256-25 zu setzen

Timer0 = 231

Enable Timer0
Enable Interrupts

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
' Save_fixflag = 0
Inv_key = 0
Rnd_setup = 0
Z_inputflag = 0
Memoryflag = 0

Pi_k = 3.141592653589793238462643383279502


' Die EEPROM-Inhalte koennten nach dem Brennen Unsinn enthalten
If Ee_fixflag <> 1 And Ee_fixflag <> 2 And Ee_fixflag <> 3 Then Ee_fixflag = 0

If Ee_displ <> &H01 Then Ee_displ = &H08

Bcheck = Checkfloat(ee_grdrad)
Errx = Bcheck And 5
If Errx > 0 Then Ee_grdrad = Pi_k / 180.0                   ' Beim Einschalten verwenden wir grd
If Ee_grdrad = 0.0 Then Ee_grdrad = Pi_k / 180.0            ' Falls noch undefiniert verwenden wir grd

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
  Dim Keyinput As Byte
  Keyinput = Inmaxkey()
  Pressedkey = Key2kdo(keyinput)

  If Pressedkey > 0 And Sleepflag > 1200 Then               ' Ein Knopf im Schlafmodus gedrueckt
      Lstkey = Pressedkey
      Pressedkey = 0
      Sleepflag = 0
      Call Wakeme
      Goto Weiter
  End If

  If Pressedkey = 0 Then Goto Nokey

  If Pressedkey = K_zweit And Lstkey = 0 Then               ' F = Zweitbelegung
     Inv_key = Not Inv_key                                  ' Toggle
     Lstkey = Pressedkey

     If Inv_key = 1 Then                                    ' gerade gedrueckt, Anzeige umschalten auf Punkte
          Ziffer_in = W_st(8)                               ' clear_output schreibt eine 0 in die 8.Anzeigestelle, wir merken uns, was da stand
          Call Save_w_st
          Call Clear_output
          W_st(8) = D_space + K_dp_disp
          S_st(8) = Ziffer_in
          If Ee_grdrad = 1.0 Then                           ' Winkelfunktionen in Bogenmass , der 5. oder 4. Dezimalpunkt leuchtet
            W_st(4) = D_space + K_dp_disp                   ' Leerzeichen + Dezimalpunkt
          Else
            W_st(5) = D_space + K_dp_disp
          End If
     Else
          Call Restore_w_st
     End If
       ' Pressedkey = 0
     Call Anzeigen
  End If

  If Pressedkey = K_zweit Then Goto Weiter


  If Inv_key = 1 And Pressedkey > 0 Then                    ' Zweitbelegung
          Pressedkey = Pressedkey + K_f_offset
          Inv_key = 0
  End If

  If Lstkey = 0 Then
     Lstkey = Pressedkey
     Ziffer_in = Digit_input(pressedkey)
     If Ziffer_in = 1 Then Call Input_number Else Call Exec_kdo
     Call Anzeigen
     Sleepflag = 0
  End If

  Goto Weiter

  Nokey:
  Lstkey = 0
  ' Wenn lange kein Knopf gedrueckt wurde, schalten wir die Anzeige auf "Sleep",
  ' Alles aus, nur der allerletzte Dezimalpunkt ist an
  ' Der Timeout (etwa 1 Minute ist hier hartcodiert
  If Inv_key = 0 Then                                       ' Wenn wir auf die Eingabe nach dem "F" warten, schlafen wir nicht
     If Sleepflag = 1200 Then
         Call Dosleep
     End If

     Incr Sleepflag

     If Sleepflag > 1200 Then
        Sleepflag = 1201
     End If
  End If

  Weiter:
  Timer0 = 231                                              '256-25
End Sub Polling


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
   W_st(8) = 0
   ' S_st(8) = 0
End Sub Clear_output


' ========================================================================
' Eine Ziffer wurde gedrueckt, wir vervollstaendigen das Eingaberegister I_st
' ========================================================================
Sub Input_number()                                          ' Eine Ziffer wurde gedrueckt, wir vervollstaendigen das Eingaberegister I_st
    Local N_1 As Byte

    ' Die eingegebene Ziffer koennte eine Speicheradresse sein
    If Memoryflag = 0 Then
       Z_inputflag = 1
       If I_pt = 2 And I_st(1) = 0 And Pressedkey > K_point Then I_pt = 1       ' "0"-Verriegelung d.h 00 am Anfang ist unsinn
       If I_pt < 9 Then
           If Pressedkey = K_point Then
              If I_pt = 1 Then
                I_st(1) = K_dp_disp
                I_pt = I_pt + 1
              Else
                I_st(i_pt -1) = I_st(i_pt -1) + K_dp_disp
              End If
           Else
              I_st(i_pt) = Pressedkey - 48
              I_pt = I_pt + 1
           End If
       End If
       ' waehrend der Eingabe geben wir das Eingaberegister selbst aus
       For N_1 = 1 To I_pt
           W_st(9 -n_1) = I_st(n_1)
       Next N_1
       For N_1 = I_pt To 8
           W_st(9 -n_1) = D_space
       Next N_1
    Else
       ' Die eingegebene Ziffer ist eine Speicheradresse!, Wir adressieren von 0 - 9, also Index 1-10
       N_1 = Pressedkey - 47
       Select Case Memoryflag
         Case 1:                                            ' STO
            Ee_mem(n_1) = Rx
            Call Beepme
         Case 2:                                            ' RCL
            Call Enter
            Rx = Ee_mem(n_1)
            Bcheck = Checkfloat(rx)
            Errx = Bcheck And 5
            If Errx > 0 Then Rx = 0.0
            Call Beepme
       End Select
       Memoryflag = 0
       Call Interpr_rx
    End If
End Sub Input_number


' ========================================================================
' Ein Kommando wurde gedrueckt, fuehren es aus und interpretieren das x-Register
' - Wenn es das erste Kommando nach einer Zahleneingabe war, uebersetzen wir est das Eingaberegister nach x
' ========================================================================
Sub Exec_kdo()
    Local Convdoubl As Double
    Local Wrk_fix_flag As Byte
    Local M_i As Byte

    If Z_inputflag = 1 Then                                 ' Vor dem Kommando wurden Ziffern eingegeben, wir muessen die Eingabe nach x uebersetzen
       If Pressedkey = K_clearx Then                        ' Löschen während der Zahleneingabe, hat nur Auswirkungen auf das Eingaberegister, nicht auf Rx
            Call Clear_input                                ' Eingaberegister leeren
            Call Clear_output
            Call Anzeigen
            Goto Finish_kdo
       Else
          Call Translate_x
          Call Enter
          Rx = Trans_input
          ' Wenn wir im Stundenmodus sind, Eingabe entsprechend korrigieren. 1.30 bedeutet 1.5 h
          If Ee_fixflag = S_disp_hm Then
             Convdoubl = Frac(rx)
             Rx = Int(rx)
             Convdoubl = Convdoubl / 0.6
             Rx = Rx + Convdoubl
          End If
       End If
       ' Z_inputflag = 0                                      ' Wir haben die eingegebenen Zahlen verwurstet
    End If

    Memoryflag = 0                                          ' Ein neues Kommando, der letzte Speicherversuch sollte jetzt aber fertig sein

    ' Machen wir uns mal ans Rechnen,
    Select Case Pressedkey
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
         Wrk_fix_flag = Ee_fixflag + 1
         If Wrk_fix_flag > 3 Then Wrk_fix_flag = 0
         Ee_fixflag = Wrk_fix_flag
         Call Beepme
      Case K_roll                                           ' Roll Down
         Lstx = Rx
         Rx = Ry
         Ry = Rz
         Rz = Rt
         Rt = Lstx
      Case K_store                                          ' STO
         Memoryflag = 1                                     ' Die Nächste Ziffer ist die Speicheradresse, gespeichert wird dann in der Zifferneingaberoutine
         Call Beepme
      Case K_recall                                         ' RCL
         Memoryflag = 2                                     ' Die Nächste Ziffer ist die Speicheradresse, gelesen wird dann in der Zifferneingaberoutine
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
      Case K_log10                                          ' LOG
         Lstx = Rx
         Rx = Log10(rx)
      Case K_10hochx                                        ' 10 hoch x
         Lstx = Rx
         Rx = 10.0 ^ Rx
      Case K_clearx                                         ' Cx  - bekommt eine Spezialbehandlung direkt in der Tastenroutine
         If Z_inputflag = 0 Then                            ' Unmotiviertes Loeschen, vorher waren keine Zahleneingaben
            Lstx = Rx
            Rx = 0.0
            Call Beepme
         ' Else
         '   Z_inputflag = 0                                 ' Enter und Lstx - Behandlung nur, wenn als Kommando ausserhalb der Zifferneingabe
         End If
      Case K_creg                                           ' Alle Register loeschen
         Lstx = Rx
         Rx = 0.0
         Ry = 0.0
         Rz = 0.0
         Rt = 0.0
         ' K_creg loescht auch die Permanentspeicher
         For M_i = 1 To 10
            Ee_mem(m_i) = 0.0
         Next M_i
         Call Beepme
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
'      Case K_hmin                                           ' H:M = Zweitbelegung der "0"
'         ' Wir setzen Das Formatflag auf S_disp_hm, Rx wird jetzt bei Ein und Ausgabe als Stunden interpretiert und in der Form h    HH.MM dargestellt
'         If Ee_fixflag = S_disp_hm Then
'            Ee_fixflag = Save_fixflag
'         Else
'            Save_fixflag = Ee_fixflag
'            Ee_fixflag = S_disp_hm
'         End If
      Case K_grd                                            ' grd
         Ee_grdrad = Pi_k / 180.0                           ' Winkelfunktionen in Grad
      Case K_rad                                            ' rad
         Ee_grdrad = 1.0                                    ' Winkelfunktionen in Bogenmass
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

      Case K_minft                                          ' m/ft
         Call Enter
         Lstx = Rx
         Rx = 0.304804
      Case K_kminmil                                        ' km/mile
         Call Enter
         Lstx = Rx
         Rx = 1.852
      Case K_mminzoll                                       ' mm/inch
         Call Enter
         Lstx = Rx
         Rx = 25.4

      End Select

Finish_kdo:
    ' Das Kommando koennte den Inhalt von "Rx" geändert haben, wir uebertragen den Inhalt in die Anzeige
    Call Interpr_rx

    Z_inputflag = 0                                         ' Kommando abgeschlossen, jetzt koennen wieder Ziffern kommen
    Call Clear_input                                        ' Eingaberegister leeren
End Sub Exec_kdo



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

   ' Anzeige leer machen
   For Ii = 1 To 8
      W_st(ii) = D_space
   Next Ii

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

         Rxwrk = Abs(rx)                                    ' Das Vorzeichen machen wir dann selbst

         If Ee_fixflag = S_disp_fix2 Then                   ' Fix2 -Anzeige

            Rxwrk = 100.0 * Rxwrk                           ' Zwei Feste Nachkommastellen
            Fixi = Int(rxwrk)
            Fixint = Fixi
            Fixfrac = Rxwrk - Fixi
            If Fixfrac > 0.5 Then Incr Fixint               ' Einfache Rundungsregel
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

         If Ee_fixflag = S_disp_float Then                  ' Float-Anzeige


           If Rx < 0.0 Then
              Ij = 7                                        ' Die Position, wo die Ziffern in der Anzeige beginnen
           Else
              Ij = 8
           End If

           If Rxwrk < 10000000.0 And Rxwrk > 0.00001 Then   ' Kleine Float-Anzeige ohne E

              Rxwrk = Round_me(rxwrk , Ij)

              Fixi = Int(rxwrk)
              Fixint = Fixi                                 ' Cast auf Integer
              Fixfrac = Rxwrk - Fixi
              ' Fixdiff = Fixfrac                             ' Cast auf integer

              If Fixint > 0 Then                            ' Die Zahl ist groesser als 1
                 ' Aufarbeiten der Vorkommastellen
                 Rxs1 = Str(fixint)
                 Snumber = Len(rxs1)

                 Snumber = Ij - Snumber                     ' Die Einerstelle
                 Incr Snumber

                 For Ii = Snumber To Ij
                    Fixdiff = Fixint Mod 10
                    W_st(ii) = Fixdiff
                    Fixint = Fixint \ 10
                 Next Ii
                 W_st(snumber) = W_st(snumber) + K_dp_disp  ' Den Dezimalpunkt
                 Ij = Snumber - 1
              Else
                 W_st(ij) = 0
                 W_st(ij) = W_st(ij) + K_dp_disp            ' Das ist erst mal die "0."
                 Decr Ij
              End If

              While Ij > 0 And Fixfrac > 0.0                ' Es sind noch stellen in der Anzeige verfügbar
                  Fixfrac = Fixfrac * 10.0
                  Fixi = Int(fixfrac)
                  Fixint = Fixi
                  W_st(ij) = Fixint
                  Fixfrac = Fixfrac - Fixi
                  Decr Ij
              Wend
           Else                                             ' Grosse Float-Anzeige mit "E"
               Call Disp_e_float(rxwrk)
           End If
           If Rx < 0.0 Then W_st(8) = D_minus
           If Rx = 0.0 Then W_st(8) = 0 + K_dp_disp         ' Das ist erst mal die "0."
         End If

         If Ee_fixflag = S_disp_eng Then                    ' Float-Anzeige mit "E"
           Call Disp_e_float(rxwrk)
           If Rx < 0.0 Then W_st(8) = D_minus
           If Rx = 0.0 Then W_st(8) = 0 + K_dp_disp         ' Das ist erst mal die "0."
         End If

         If Ee_fixflag = S_disp_hm Then                     ' H:M - Anzeige
            ' Der Wert im Rx sind Stunden mit komma, rechnen wir erst mal in Minuten um:
            Rxwrk = Rxwrk * 60.0                            ' Minuten
            Fixi = Int(rxwrk)
            Fixint = Fixi
            Fixfrac = Rxwrk - Fixi
            If Fixfrac > 0.5 Then Incr Fixint               ' Einfache Rundungsregel

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
            W_st(8) = 24                                    ' ein "h" an der ersten Stelle
         End If
      Else                                                  ' Zeichenkette "Error" Ausgeben
        W_st(8) = D_space
        W_st(7) = D_char_e
        W_st(6) = D_char_r
        W_st(5) = D_char_r
        W_st(4) = D_char_o
        W_st(3) = D_char_r
        W_st(2) = D_space
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
        If Stelle > 127 Then                                ' Diese Stelle hat einen Dezimalpunkt
           Stelle = Stelle - K_dp_disp                      ' 128.0
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
' War die eingabe eine Ziffer oder ein Kommando?
' ========================================================================
Function Digit_input(inputkey As Byte) As Bit
   Digit_input = 0
   If Inputkey > 47 And Inputkey < 58 Then Digit_input = 1
   If Inputkey = K_point Then Digit_input = 1               ' Der Dezimalpunkt
End Function Digit_input


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
       Key2kdo = 5                                          ' "."
     Case 56
       Key2kdo = 6                                          ' "Enter"

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
       Key2kdo = K_sinus                                    ' SIN
     Case 34
       Key2kdo = K_cosinus                                  ' COS
     Case 36
       Key2kdo = K_tangens                                  ' TAN
     Case 40
       Key2kdo = K_logn                                     ' LN
     Case 48
       Key2kdo = K_log10                                    ' LOG
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
     Case 20                                                ' A
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
     Case 26                                                ' P
       Convert = 103
     Case 27                                                ' n
       Convert = 21
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
   Disable Interrupts
   Call Dosleep
   Waitms 100
   Call Wakeme
   Enable Interrupts
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
' Schleife ueber das Anzeigefeld, Umwandlung in 7segmentcode
' Input ist nicht Rx, sondern das Anzeigeregister w_st
' ========================================================================
Sub Anzeigen()
   Local Disp7code As Byte
   Local N_1 As Byte
   Local N_2 As Byte
   For N_1 = 1 To 8
      N_2 = 9 - N_1                                         ' Durch einen Loetfehler ist der Index hier andersherum
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

' ========================================================================
' EOF
' ========================================================================