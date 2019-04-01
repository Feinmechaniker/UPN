' ****************************************************************************
'
' OSCTest.bas
' Test des OSCAL-Byte für die Kalibrierung der Baudrate
'
' Joe G.
' 31.03.2019
' ****************************************************************************

$regfile = "m328pdef.dat"                                   ' ATmega328-Deklarationen


$crystal = 1000000                                          ' Kein Quarz: 1MHz MHz
$baud = 9600                                                ' Baudrate der UART: 9600 Baud

$hwstack = 196                                              ' hardware stack (32)
$swstack = 196                                              ' SW stack (10)
$framesize = 256                                            ' frame space (40)



Config Portb = Output

Dim B As Byte
For B = &H30 To &H80
  Osccal = B
  Waitms 500
  Print "Kalibrierung der Baudrate, Ausgabe des OSCAL Register :" ; B
Next
Osccal = 30



