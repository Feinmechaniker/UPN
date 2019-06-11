'------------------------------------------------------------------------------
' Projektname              : Query_Keypad.bas
' Copyright                : (c) 2001-2019, j.grabow <grabow@amesys.de> www.amesys.de
' Beschreibung             : Tastaturabfrage einer 5x8 Matrix
' Compiler                 : BASCOM 2.0.8.1
' Version                  : 01.00
' Reviev                   : Beta
'------------------------------------------------------------------------------
' Hardwarebeschreibungen
' Controller               : ATMega1284P
' Oscillator               : Crystal Clock 11.0597 MHz
' UART                     : 115200 Baud
'------------------------------------------------------------------------------
' Softwarebeschreibung
' ermittelt den Scancode einer 5x8 Matrix
'------------------------------------------------------------------------------
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
'------------------------------------------------------------------------------

' Programmhistorie
' 11.06.19  V. 01.00 Startversion
'------------------------------------------------------------------------------


$regfile = "m1284pdef.dat"                                  ' Prozessor ATmega1284P
$crystal = 11059700                                         ' Quarzfrequenz 11.0597 MHz
$baud = 115200                                              ' Baudrate der UART: 115200 Baud

$hwstack = 196                                              ' hardware stack (32)
$swstack = 196                                              ' SW stack (10)
$framesize = 256                                            ' frame space (40)

Config Debounce = 10                                        ' when the config statement is not used a default of 25mS

' -----------------------------------------------------------------------------
' Port declarations
' -----------------------------------------------------------------------------

' Keypad Column PC2 - PC6
DDRC = &B01111100                                           ' PC2-PC6 as Output

' Keypad Row PA0 - PA7
DDRA = &B0000000                                            ' all Pins as Input
PORTA = &B111111111                                         ' all Pins pull-up

' -----------------------------------------------------------------------------
' Variable declarations
' -----------------------------------------------------------------------------
Dim Column as Byte                                          ' Column Counter
Dim Row as Byte                                             ' Row Counter
Dim Key as Byte                                             ' contains key number

' -----------------------------------------------------------------------------
' Function and subroutine declarations
' -----------------------------------------------------------------------------
Declare Function Query_Keypad() as Byte                     ' determines keyboard code


' -----------------------------------------------------------------------------
' Program
' -----------------------------------------------------------------------------
Do
   Key = Query_Keypad()                                     ' get Keycode
   If Key <> 0 Then
     Print "Keycode " ; Key                                 ' Print Keycode
   End If
Loop

End


' -----------------------------------------------------------------------------
' Function and subroutine
' -----------------------------------------------------------------------------
Function Query_Keypad() as Byte                             ' needs about 225us
   'PinA=&B11111111                                          ' only for debugging
   Key = 0                                                  ' clear Keycode
   For Column = 1 To 5                                      ' all Columns
      PORTC = &B01111100                                    ' Column Bitmask (PC2-PC6 High)
      If Column = 1 Then Reset PortC.2
      If Column = 2 Then Reset PortC.3
      If Column = 3 Then Reset PortC.4
      If Column = 4 Then Reset PortC.5
      If Column = 5 Then Reset PortC.6
      For Row = 1 To 8                                      ' all Rows
         Select Case Row
            Case 1 : Debounce PinA.0 , 0 , Calc_key , Sub
            Case 2 : Debounce PinA.1 , 0 , Calc_key , Sub
            Case 3 : Debounce PinA.2 , 0 , Calc_key , Sub
            Case 4 : Debounce PinA.3 , 0 , Calc_key , Sub
            Case 5 : Debounce PinA.4 , 0 , Calc_key , Sub
            Case 6 : Debounce PinA.5 , 0 , Calc_key , Sub
            Case 7 : Debounce PinA.6 , 0 , Calc_key , Sub
            Case 8 : Debounce PinA.7 , 0 , Calc_key , Sub
         End Select
      Next Row
   Next Column
   Query_Keypad = Key
End Function Query_Keypad()

Calc_key:
   Select Case Row
      Case 1 : Key = Column
      Case 2 : Key = Column + 5
      Case 3 : Key = Column + 10
      Case 4 : Key = Column + 15
      Case 5 : Key = Column + 20
      Case 6 : Key = Column + 25
      Case 7 : Key = Column + 30
      Case 8 : Key = Column + 35
   End Select
Return