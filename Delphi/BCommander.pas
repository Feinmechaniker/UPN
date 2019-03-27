{------------------------------------------------------------------------------}
// Boris-Commander
//
// Copyright (c) 1990-2019 j.grabow <grabow@amesys.de> www.amesys.de
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
{------------------------------------------------------------------------------}
{ Programmname             : BCommander.pas                                    }
{ Copyright                : (c) 2090-2019, AMESYS                             }
{ Beschreibung             : Tool für UPN-Taschenrechner BORIS                 }
{ Compiler                 : Delphi 10.3.1                                     }
{ Version                  : 00.3                                              }
{ Reviev                   : Beta                                              }
{------------------------------------------------------------------------------}
{ Programmhistorie                                                             }
{ 20.03.19  V. 00.1 Startversion                                               }
{ 21.03.19  V. 00.2 Dateiarbeit                                                }
{ 22.03.19  V. 00.3 Disassembler                                               }
{ 27.03.19  V. 00.4 Disassembler erweitert, Dezimaldarstellung                 }
{------------------------------------------------------------------------------}


unit BCommander;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, CPort, CPortCtl, IniFiles, Menus, Vcl.Grids, Vcl.ValEdit;

type
  TForm1 = class(TForm)
    ComPort: TComPort;
    GroupBox1: TGroupBox;
    Button_Open: TButton;
    Button_Settings: TButton;
    GroupBox2: TGroupBox;
    Button1: TButton;
    Button2: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Button3: TButton;
    Button4: TButton;
    SaveDialog1: TSaveDialog;
    GroupBox3: TGroupBox;
    Button5: TButton;
    Label3: TLabel;
    Label4: TLabel;
    Button6: TButton;
    StringGrid1: TStringGrid;
    OpenDialog1: TOpenDialog;
    Button8: TButton;
    Button7: TButton;
    procedure Button_OpenClick(Sender: TObject);
    procedure Button_SettingsClick(Sender: TObject);
//    procedure Button_SendClick(Sender: TObject);
    procedure ComPortOpen(Sender: TObject);
    procedure ComPortClose(Sender: TObject);
    procedure ComPortRxChar(Sender: TObject; Count: Integer);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure MemoChange(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure StringGrid1Click(Sender: TObject);

  private
    { Private declarations }
    FIni:TMemIniFile;
    FInitFlag:Boolean;

  public
    { Public declarations }
  end;

const
  Mem_max = 200;                                         // maximale Datenlänge

type
  BefehlsType = Array[0..128] of String[6];

  TR_Type = Array[1..2] of String[2];                      // High- und Lowteil

var
  Form1   : TForm1;
  temp    : byte;
  DatL    : Word;                              // Datenlänge des Empfangsstring
  Paket   : String;                                      // UART Empfangsstring
  Daten_H : String;                                    // Programmdaten als HEX
  Daten_S : String;                                 // Programmdaten als String
  TR_Dat  : Array[0..99] of TR_Type;                 // Datenspeicher als Array
  Befehl  : BefehlsType;                                   // Liste der Befehle

implementation

{$R *.DFM}

//------------------------------------------------------------------------------
// wandelt ein HEX-String um Binärformat um
//------------------------------------------------------------------------------
function HexToBin(Hex: string): Byte;
var
  B: Byte;
  C: Char;
  Idx, Len: Integer;
begin
  Len := Length(Hex);
  If Len = 0 then Exit;
  Idx := 1;
  repeat
    C := Hex[Idx];
    case C of
      '0'..'9': B := Byte((Ord(C) - Ord('0')) shl 4);
      'A'..'F': B := Byte(((Ord(C) - Ord('A')) + 10) shl 4);
      'a'..'f': B := Byte(((Ord(C) - Ord('a')) + 10) shl 4);
    else
      raise Exception.Create('bad hex data');
    end;
    C := Hex[Idx+1];
    case C of
      '0'..'9': B := B or Byte(Ord(C) - Ord('0'));
      'A'..'F': B := B or Byte((Ord(C) - Ord('A')) + 10);
      'a'..'f': B := B or Byte((Ord(C) - Ord('a')) + 10);
    else
      raise Exception.Create('bad hex data');
    end;
    Inc(Idx, 2);
    Result := B;
  until Idx > Len;
end;

//------------------------------------------------------------------------------
// wandelt ein String in HEX-Darstellung um
//------------------------------------------------------------------------------
function StringToHex(S: String): String;                       // Hilfsfunktion
var I: Integer;
begin
  Result:= '';
  for i := 1 to length (S) do
    Result:= Result+IntToHex(ord(S[i]),2);
end;

//------------------------------------------------------------------------------
// Delay Funktion
//------------------------------------------------------------------------------
procedure Delay(msec: integer);                                // Hilfsfunktion
var start, stop: LongInt;
begin
  start := GetTickCount;
  repeat
    stop := GetTickCount;
    Application.ProcessMessages;
  until (stop-start)>=msec;
end;


//------------------------------------------------------------------------------
// Connect Funktion um Taschenrechner mit UART zu verbinden
//------------------------------------------------------------------------------
procedure TForm1.Button1Click(Sender: TObject);
begin
  DatL := 0;                                             // Datenlänge auf null
  Paket := '';                                                // Paket ist leer
  ComPort.WriteStr(CHR($AA));                         // sende Connect Kommando
  Delay(1500);                               // 1.5 Sekunden auf Antwort warten
//  DatL := 1;                                                     // Debugging
  if DatL = 0 then                                          // nichts empfangen
   Application.MessageBox( PChar('Boris antwortet nicht!'), 'Error', MB_OK);
  if DatL > 0 then
  begin
   Button1.Enabled := false;         // Connect kann nicht mehr betätigt werden
   Button2.Enabled := true;                       // Disconnect Button sichtbar
   Button3.Enabled := true;                             // Load Button sichtbar
   Button4.Enabled := true;                            // Write Button sichtbar
   Label4.Caption := '';                                          // PC löschen
   Label1.Caption := Paket;                          // Versionsnummer anzeigen
//   Paket := StringToHex(Temp_Str);                // Datenpaket bauen
//   Memo.Text := Paket + CHR($0D) + CHR($0A);
//   Memo.Text := Memo.Text + InttoStr(DatL);
  end;
end;


//------------------------------------------------------------------------------
// Disconnect Funktion für Taschenrechner
//------------------------------------------------------------------------------
procedure TForm1.Button2Click(Sender: TObject);
begin
 ComPort.WriteStr(CHR($FF));                        // sende Disconnct Kommando
 Button1.Enabled := true;                            // Connect Button sichtbar
 Button2.Enabled := false;                      // Disconnect Button unsichtbar
 Button3.Enabled := false;                            // Load Button unsichtbar
 Button4.Enabled := false;                           // Write Button unsichtbar
 Label1.Caption := '';                                // Versionsnummer löschen
   Label4.Caption := '';                                          // PC löschen
end;


//------------------------------------------------------------------------------
// Load-Button (lade Programm aus Taschenrechner)
//------------------------------------------------------------------------------
procedure TForm1.Button3Click(Sender: TObject);
var
  i,j      : Word;                                                // PC-Counter

begin
// Memo.Text := '';
 Paket := '';                                                     // Paket leer
 Daten_S := '';                                               // Datensatz leer
 Daten_H := '';
 DatL := 0;                                                  // Datenlänge null
 ComPort.WriteStr(CHR($52));                             // sende Load Kommando
 Delay(1000);                                  // eine Sekunde auf Daten warten
 if DatL = 0 then                                           // nichts empfangen
  Application.MessageBox( PChar('Keine Daten empfangen!'), 'Error', MB_OK);
 if DatL > Mem_max then
  Application.MessageBox( PChar('Datensatz zu groß'), 'Error', MB_OK)
  else                                                       // Daten empfangen
   begin
    Button1.Enabled := true;                         // Connect Button sichtbar
    Button2.Enabled := false;                   // Disconnect Button unsichtbar
    Button3.Enabled := false;                         // Load Button unsichtbar
    Button4.Enabled := false;                        // Write Button unsichtbar
    Label1.Caption := '';                             // Versionsnummer löschen
    Label4.Caption := InttoStr(DatL div 2);              // PC-Counter anzeigen
    Daten_H := Paket;                              // Daten aus UART übernehmen
    Daten_S := StringToHex(Daten_H);                        // Datenpaket bauen
//    Memo.Text := Daten_S + CHR($0D) + CHR($0A);
    j := 0;                                                        // Index = 0
    for i := 1 to (Datl div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      TR_Dat[i-1,1] := Daten_S[j+1] + Daten_S[j+2];         // Code in Speicher
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
      TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];      // Adresse in Speicher
      j := j+4;
     end; // for i := 0
   end; // Dat_L <= Mem_max
end;

//------------------------------------------------------------------------------
// Write-Button (speichere Programm im Taschenrechner)
//------------------------------------------------------------------------------
procedure TForm1.Button4Click(Sender: TObject);
begin
 ComPort.WriteStr(CHR($53));     // sende Save Kommando, Boris wartet auf Daten
 Delay(1000);                                            // eine Sekunde warten
 ComPort.WriteStr(Daten_H);                                  // sende Datensatz
 Button1.Enabled := true;                            // Connect Button sichtbar
 Button2.Enabled := false;                      // Disconnect Button unsichtbar
 Button3.Enabled := false;                            // Load Button unsichtbar
 Button4.Enabled := false;                           // Write Button unsichtbar
 Label1.Caption := '';                                // Versionsnummer löschen
 Label4.Caption := InttoStr(DatL div 2);                 // PC-Counter anzeigen
end;

//------------------------------------------------------------------------------
// Save-Dialog (sichere Programm auf PC)
//------------------------------------------------------------------------------
procedure TForm1.Button5Click(Sender: TObject);
var
  F : Textfile;                                                 // Programmfile
begin
// Savedialog1.FileName := '';                               // Namensvorschlag
 Savedialog1.Filter:='Programmdateien | *.bor';             // Dateierweiterung
 SaveDialog1.Execute();                                       // Save ausführen
 AssignFile(F, SaveDialog1.Filename);
 Rewrite(F);                                                    // erzeugt File
 Write(F,Daten_H);                           // Datensatz als HEX-Daten sichern
 CloseFile(F);
end;

//------------------------------------------------------------------------------
// Load-Dialog (lade Programm von PC)
//------------------------------------------------------------------------------
procedure TForm1.Button6Click(Sender: TObject);
var
  F : Textfile;                                                 // Programmfile
  i,j : Word;                                                          // Index
begin
 Daten_H := '';                                             // Speicher löschen
 Daten_S := '';
// Opendialog1.FileName := '';                               // Namensvorschlag
 Opendialog1.Filter:='Programmdateien | *.bor';             // Dateierweiterung
 OpenDialog1.Execute();                                       // Open ausführen
 AssignFile(F, OpenDialog1.Filename);
 Reset(F);                                                      // Datei öffnen
 Read(F,Daten_H);                                                // Daten lesen
 CloseFile(F);                                               // Datei schließen
 DatL := Length(Daten_H);
 if DatL > Mem_max then
  Application.MessageBox( PChar('Datensatz zu groß'), 'Error', MB_OK)
  else                                                      // Daten darstellen
   begin
    Daten_S := StringToHex(Daten_H);                        // Datenpaket bauen
//    Memo.Text := Daten_S + CHR($0D) + CHR($0A);
    j := 0;                                                        // Index = 0
    for i := 1 to (DatL div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      TR_Dat[i-1,1] := Daten_S[j+1] + Daten_S[j+2];         // Code in Speicher
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
      TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];      // Adresse in Speicher
      j := j+4;
     end; // for i := 0
   end; // else
end;


//------------------------------------------------------------------------------
// ASM-Dialog (schaltet von HEX auf ASM-Darstellung)
//------------------------------------------------------------------------------
procedure TForm1.Button7Click(Sender: TObject);
Var
  i,j   : Word;                                                        // Index
  temp  : String;
  Index : Byte;                                     // Index im Befehlsspeicher
  Adr   : Byte;                                                      // Adresse

begin
 if Button7.Caption = 'ASM' then                        // Button steht auf ASM
  begin
    j := 0;                                                        // Index = 0
    for i := 1 to (DatL div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := Format('%d',[i-1]);       // PC-Counter dezimal
      temp := Daten_S[j+1] + Daten_S[j+2];                        // Code holen
      Index := HexToBin(temp);                     // Code in Binärwert wandeln
      StringGrid1.Cells[1,i] := Befehl[Index];                 // Code anzeigen
      TR_Dat[i-1,1] := Daten_S[j+1] + Daten_S[j+2];         // Code in Speicher
      if (Index=7) OR                                                    // STO
         (Index=8) OR                                                    // RCL
         (Index=10) OR                                                  // GOTO
         (Index=11) OR                                                 // GOSUB
         (Index=74) OR                                                   // X>0
         (Index=75) OR                                                   // X=0
         (Index=76) then                                                 // X<0
      begin
       temp := Daten_S[j+3] + Daten_S[j+4];                    // Adresse holen
       Adr := HexToBin(temp);                   // Adresse in Binärwert wandeln
       StringGrid1.Cells[2,i] := Format('%.2d',[Adr]);       // Adresse dezimal
//    StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
//    TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];      // Adresse in Speicher
      end
      else                                            // keine Adresse anzeigen
       begin
       StringGrid1.Cells[2,i] := '';         // Adresse
       TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];     // Adresse in Speicher
       end;
      j := j+4;
     end; // for i := 0
   Button7.Caption := 'HEX';                          // Button auf Hex stellen
  end // ASM
  else                                                  // Button stand auf Hex
   begin
    j := 0;                                                        // Index = 0
    for i := 1 to (DatL div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      TR_Dat[i-1,1] := Daten_S[j+1] + Daten_S[j+2];         // Code in Speicher
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
      TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];      // Adresse in Speicher
      j := j+4;
     end; // for i := 0
    Button7.Caption := 'ASM';                         // Button auf ASM stellen
   end;
end;


//------------------------------------------------------------------------------
// Clear-Dialog (lösche Speicher)
//------------------------------------------------------------------------------
procedure TForm1.Button8Click(Sender: TObject);
var
  F : Textfile;                                                 // Programmfile
  i,j : Word;                                                          // Index
begin
 Daten_H := '';
 for i := 0 to Mem_max-1 do
  Daten_H := Daten_H + CHR(0);
  Daten_S := StringToHex(Daten_H);                          // Datenpaket bauen
 j := 0;                                                           // Index = 0
 for i := 1 to (Mem_max div 2) do                  // bis ende Programmspeicher
  begin
   StringGrid1.Cells[0,i] := InttoStr(i-1);                       // PC-Counter
   StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];               // Code
   TR_Dat[i-1,1] := Daten_S[j+1] + Daten_S[j+2];            // Code in Speicher
   StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];            // Adresse
   TR_Dat[i-1,2] := Daten_S[j+3] + Daten_S[j+4];         // Adresse in Speicher
   j := j+4;
  end; // for i := 0


end;

//------------------------------------------------------------------------------
// COM-Port Button Click
//------------------------------------------------------------------------------
procedure TForm1.Button_OpenClick(Sender: TObject);
begin
  if ComPort.Connected then
    ComPort.Close
  else
    ComPort.Open;
end;

//------------------------------------------------------------------------------
// COM-Port open
//------------------------------------------------------------------------------
procedure TForm1.ComPortOpen(Sender: TObject);
begin
  Button_Open.Caption := 'Close';
  DatL := 0;                                                 // Datenlänge null
  Paket := '';                                                // Paket ist leer
  Button1.Enabled := true                            // Connect Button sichtbar
end;

//------------------------------------------------------------------------------
// COM-Port close
//------------------------------------------------------------------------------
procedure TForm1.ComPortClose(Sender: TObject);
begin
  if Button_Open <> nil then
   Button_Open.Caption := 'Open';
   Button1.Enabled := false;                       // Connect Button unsichtbar
   Button2.Enabled := false;                    // Disconnect Button unsichtbar
   Button3.Enabled := false;                          // Load Button unsichtbar
   Button4.Enabled := false;                         // Write Button unsichtbar
   Label4.Caption := '';                                          // PC löschen
   Label1.Caption := '';                              // Versionsnummer löschen
end;

//------------------------------------------------------------------------------
// COM-Port Settings Click
//------------------------------------------------------------------------------
procedure TForm1.Button_SettingsClick(Sender: TObject);
begin
  ComPort.ShowSetupDialog;                  // öffne Dialogfenster für Settings
end;

{
procedure TForm1.Button_SendClick(Sender: TObject);
var
  Str: String;
begin
  Str := Edit_Data.Text;
  if NewLine_CB.Checked then
    Str := Str + #13#10;
  ComPort.WriteStr(Str);
end;
}

//------------------------------------------------------------------------------
// Empfangsroutine wird ausgelöst, sobald ein Zeichen im Puffer ist
// Paket : Empfangsdaten (String)
// DatL  : Datenlänge    (Word)
//------------------------------------------------------------------------------
procedure TForm1.ComPortRxChar(Sender: TObject; Count: Integer);
var
  Temp_Str : String;                                          // Empfangsstring

begin
  ComPort.ReadStr(Temp_Str, Count);
  Paket := Paket + Temp_Str;                            // Empfangsstring bauen
  DatL := DatL + Count;                                 // Datenlänge mitzählen
end;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// Programm wird durch Anwender beendet
//------------------------------------------------------------------------------
procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   if Assigned(FIni) then begin
     FIni.WriteString('ComPort', 'ComPort', ComPort.Port );
     FIni.WriteString('ComPort','BaudRate', BaudRateToStr( ComPort.BaudRate ) );
     FIni.WriteString('ComPort','FlowControl', FlowControlToStr(ComPort.FlowControl.FlowControl ));
     FIni.UpdateFile;
     FIni.Free;
   end;
end;


//------------------------------------------------------------------------------
// Programmstart durch Anwender
//------------------------------------------------------------------------------
procedure TForm1.FormCreate(Sender: TObject);
begin
 if not FInitFlag then begin   // wenn kein Terminal.ini-File existiert, File anlegen bzw. Änderungen übernehmen
   FInitFlag := true;
   FIni := TMemIniFile.Create( ExtractFilePath(Application.ExeName)+'BC.ini');
   ComPort.Port := FIni.ReadString('ComPort', 'ComPort',ComPort.Port);
   ComPort.BaudRate := StrToBaudRate( FIni.ReadString('ComPort','BaudRate', '9600'));
   ComPort.FlowControl.FlowControl := StrToFlowControl( FIni.ReadString('ComPort','FlowControl', 'none'));
  end;

 ComPort.DiscardNull := false;  // Null Terminierung bei Strings abschalten !!!

 StringGrid1.ColCount := 3;                                        // 3 Spalten
 StringGrid1.RowCount := (Mem_max div 2)+1;                      // Zeilenlänge
 StringGrid1.Font.Style := [fsBold];
 StringGrid1.Cells[0,0] := 'PC';                                 // Überschrift
 StringGrid1.Cells[1,0] := 'Code';                               // Überschrift
 StringGrid1.Cells[2,0] := 'Adr';                                // Überschrift
end;

procedure TForm1.FormShow(Sender: TObject);
begin
{
 if not FInitFlag then begin   // wenn kein Terminal.ini-File existiert, File anlegen bzw. Änderungen übernehmen
   FInitFlag := true;
   FIni := TMemIniFile.Create( ExtractFilePath(Application.ExeName)+'terminal.ini');
   ComPort.Port := FIni.ReadString('ComPort', 'ComPort',ComPort.Port);
   ComPort.BaudRate := StrToBaudRate( FIni.ReadString('ComPort','BaudRate', '9600'));
   ComPort.FlowControl.FlowControl := StrToFlowControl( FIni.ReadString('ComPort','FlowControl', 'none'));
   ComLed1.Kind := lkRedLight;                            // Connet LED ist rot
  end;
}
end;


procedure TForm1.MemoChange(Sender: TObject);
begin
  temp := 1;
end;



procedure TForm1.StringGrid1Click(Sender: TObject);
begin
 temp := 0;
end;

Procedure Init_Befehle;
begin
 Befehl[0] := 'NOP';
 Befehl[1] := '+';
 Befehl[2] := '-';
 Befehl[3] := '*';
 Befehl[4] := '/';
 Befehl[5] := '.';
 Befehl[6] := 'ENTER';
 Befehl[7] := 'STO';
 Befehl[8] := 'RCL';
 Befehl[9] := 'SQRT';
 Befehl[10] := 'GOTO';
 Befehl[11] := 'GOSUB';
 Befehl[12] := 'RETURN';
 Befehl[13] := 'LN';
 Befehl[14] := 'HALT';
 Befehl[15] := 'CX';
 Befehl[16] := 'X^Y';
 Befehl[17] := 'X<->Y';
 Befehl[18] := 'STO+';
 Befehl[19] := 'STO-';
 Befehl[20] := 'STO*';
 Befehl[21] := 'STO/';
 Befehl[48] := '0';
 Befehl[49] := '1';
 Befehl[50] := '2';
 Befehl[51] := '3';
 Befehl[52] := '4';
 Befehl[53] := '5';
 Befehl[54] := '6';
 Befehl[55] := '7';
 Befehl[56] := '8';
 Befehl[57] := '9';
 Befehl[65] := 'DIMM';
 Befehl[66] := 'CHS';
 Befehl[67] := 'RND';
 Befehl[68] := '1/X';
 Befehl[69] := 'FIX';
 Befehl[70] := 'RDN';
 Befehl[73] := 'SQR';
 Befehl[74] := 'X>0';
 Befehl[75] := 'X=0';
 Befehl[76] := 'X<0';
 Befehl[77] := 'E^X';
 Befehl[78] := 'PRG';
 Befehl[79] := 'NOP';
 Befehl[80] := 'PI';
 Befehl[81] := 'LSTX';
 Befehl[112] := 'GRD';
 Befehl[113] := 'INT';
 Befehl[114] := 'FRAC';
 Befehl[115] := 'ABS';
 Befehl[116] := 'ASIN';
 Befehl[117] := 'ACOS';
 Befehl[118] := 'ATAN';
 Befehl[119] := 'SIN';
 Befehl[120] := 'COS';
 Befehl[121] := 'TAN';
end;


Begin
 Init_Befehle;
End.
