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
{ 28.03.19  V. 00.5 Assembler begonnen                                         }
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
    GroupBox4: TGroupBox;
    StringGrid2: TStringGrid;
    Button9: TButton;
    Button10: TButton;
    Button11: TButton;
    Button12: TButton;
    procedure Button_OpenClick(Sender: TObject);
    procedure Button_SettingsClick(Sender: TObject);
    procedure ComPortOpen(Sender: TObject);
    procedure ComPortClose(Sender: TObject);
    procedure ComPortRxChar(Sender: TObject; Count: Integer);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure StringGrid1Click(Sender: TObject);
    procedure StringGrid2Click(Sender: TObject);
    procedure Button10Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure Button12Click(Sender: TObject);

  private
    { Private declarations }
    FIni:TMemIniFile;
    FInitFlag:Boolean;

  public
    { Public declarations }
  end;

const
  Mem_max = 200;                                // maximale Datenlänge (2 Byte)
  PC_max  = 99;                                            // (Mem_max / 2) - 1

type
  BefehlsType = Array[0..127] of String[6];
  ZahlType    = Array[0..255] of String[3];

  Prog_Type = Array[1..2] of String[6];       // Programmcode High- und Lowteil

var
  Form1    : TForm1;
  temp     : byte;
  DatL     : Word;                             // Datenlänge des Empfangsstring
  Paket    : String;                                     // UART Empfangsstring
  Daten_H  : String;                                   // Programmdaten als HEX
  Daten_S  : String;                                // Programmdaten als String
  CDaten_H : Array[0..Mem_Max] of Char;// compilierte Programmdaten in HEX-Form
//  CDaten_H : String;// compilierte Programmdaten in HEX-Form
  Prog_Dat : Array[0..PC_max] of Prog_Type;                     // Programmcode
  Befehl   : BefehlsType;                                  // Liste der Befehle
  Zahl     : ZahlType;                            // Liste der möglichen Zahlen

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
    j := 0;                                                        // Index = 0
    for i := 1 to (Datl div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
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
    j := 0;                                                        // Index = 0
    for i := 1 to (DatL div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
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
      if Index <> 255 then StringGrid1.Cells[1,i] := Befehl[Index]  // Code anzeigen
       else StringGrid1.Cells[1,i] := '';       // bei 255 (FF) nichts anzeigen
      if (Index=7) OR                                                    // STO
         (Index=8) OR                                                    // RCL
         (Index=10) OR                                                  // GOTO
         (Index=11) OR                                                 // GOSUB
         (Index=18) OR                                                  // STO+
         (Index=19) OR                                                  // STO-
         (Index=20) OR                                                  // STO*
         (Index=21) OR                                                  // STO/
         (Index=74) OR                                                   // X>0
         (Index=75) OR                                                   // X=0
         (Index=76) then                                                 // X<0
      begin                                      // zusätzlich Adresse anzeigen
       temp := Daten_S[j+3] + Daten_S[j+4];                    // Adresse holen
       Adr := HexToBin(temp);                   // Adresse in Binärwert wandeln
       StringGrid1.Cells[2,i] := Format('%d',[Adr]);         // Adresse dezimal
      end
      else StringGrid1.Cells[2,i] := '';              // keine Adresse anzeigen
      j := j+4;
     end; // for i := 0
   Button7.Caption := 'HEX';                          // Button auf Hex stellen
   Button11.Enabled := true;                          // Grid überladen möglich
  end // ASM
  else                                                  // Button stand auf Hex
   begin
    j := 0;                                                        // Index = 0
    for i := 1 to (DatL div 2) do                  // bis ende Programmspeicher
     begin
      StringGrid1.Cells[0,i] := InttoStr(i-1);                    // PC-Counter
      StringGrid1.Cells[1,i] := Daten_S[j+1] + Daten_S[j+2];            // Code
      StringGrid1.Cells[2,i] := Daten_S[j+3] + Daten_S[j+4];         // Adresse
      j := j+4;
     end; // for i := 0
    Button7.Caption := 'ASM';                         // Button auf ASM stellen
    Button11.Enabled := false;                  // Grid überladen nicht möglich
   end;
end;


//------------------------------------------------------------------------------
// Clear-Dialog (lösche Speicher)
//------------------------------------------------------------------------------
procedure TForm1.Button8Click(Sender: TObject);
var
  i,j : Word;                                                          // Index
begin
 Daten_H := '';
 for i := 0 to Mem_max-1 do
  Daten_H := Daten_H + CHR(0);
  Daten_S := StringToHex(Daten_H);                          // Datenpaket bauen
 j := 0;                                                           // Index = 0
 for i := 0 to PC_max do                           // bis Ende Programmspeicher
  begin
   StringGrid1.Cells[0,i+1] := InttoStr(i);                       // PC-Counter
   StringGrid1.Cells[1,i+1] := Daten_S[j+1] + Daten_S[j+2];             // Code
   StringGrid1.Cells[2,i+1] := Daten_S[j+3] + Daten_S[j+4];          // Adresse
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
 Button11.Enabled := false;                     // Grid überladen nicht möglich
 Button12.Enabled := false;                     // Grid überladen nicht möglich

 StringGrid1.ColCount := 3;                                        // 3 Spalten
 StringGrid1.RowCount := PC_max+2;                               // Zeilenlänge
 StringGrid1.Font.Style := [fsBold];
 StringGrid1.Options := [goFixedVertLine,goFixedHorzLine,goVertLine,goHorzLine,goRangeSelect,GoDrawFocusSelected];
 StringGrid1.Cells[0,0] := 'PC';                                 // Überschrift
 StringGrid1.Cells[1,0] := 'Code';                               // Überschrift
 StringGrid1.Cells[2,0] := 'Adr';                                // Überschrift

 StringGrid2.ColCount := 3;                                        // 3 Spalten
 StringGrid2.RowCount := PC_max+2;                               // Zeilenlänge
 StringGrid2.Options := [goFixedVertLine,goFixedHorzLine,goVertLine,goHorzLine,goRangeSelect,
 GoDrawFocusSelected,GoAlwaysShowEditor,GoEditing,goTabs,goRangeSelect];
 StringGrid2.Font.Style := [fsBold];
 StringGrid2.Cells[0,0] := 'PC';                                 // Überschrift
 StringGrid2.Cells[1,0] := 'Code';                               // Überschrift
 StringGrid2.Cells[2,0] := 'Adr';                                // Überschrift


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

{
procedure TForm1.MemoChange(Sender: TObject);
begin
  temp := 1;
end;
}

procedure TForm1.StringGrid1Click(Sender: TObject);
begin
 temp := 0;
end;

//------------------------------------------------------------------------------
// Compilermeldungen
//------------------------------------------------------------------------------
procedure TForm1.Edit1Change(Sender: TObject);
begin
 temp := 1;
end;

//------------------------------------------------------------------------------
// Gitter synchronisieren (HEX-Gitter to Assembler-Gitter
//------------------------------------------------------------------------------
procedure TForm1.Button11Click(Sender: TObject);
Var i,j : Byte;
begin
 for i := 0 to 2 do
   for j := 1 to PC_max+1 do StringGrid2.Cells[i,j] := StringGrid1.Cells[i,j];
end;


//------------------------------------------------------------------------------
// Gitter synchronisieren (Assembler-Gitter to Hex-Gitter
//------------------------------------------------------------------------------
procedure TForm1.Button12Click(Sender: TObject);
var i : Integer;
begin
 Daten_H := '';                                          // alten Daten löschen
 Daten_S := '';                                          // alten Daten löschen
 for i := 0 to Mem_max-1 do Daten_H := Daten_H + CDaten_H[i];     // umkopieren
 DatL := Length(Daten_H);                                    // Länge bestimmen
 Daten_S := StringToHex(Daten_H);                           // Datenpaket bauen
 Button7.Click;                                                     // anzeigen
 Button7.Click;                                                     // anzeigen
end;


//------------------------------------------------------------------------------
// Test auf Zahl im Code
//------------------------------------------------------------------------------
function IF_Number(const Zeichen:String): Byte;
var
  i : integer;
  Flag : Boolean;
  Str  : String;
begin
 Str := '';
 Flag := false;
 Result := 1;
 for i := 1 to length(Zeichen) do                        // nach Ziffern suchen
  begin
   if (ord(Zeichen[i]) >= 48) and (ord(Zeichen[i]) <= 57) then
    begin                                                   // Ziffern gefunden
     Str := Str + Zeichen[i];
     Flag := true;
    end;
  end; // end for i
 i := 1000;
 if Flag then i := StrToInt(Str);                          // Ziffern umwandeln
 if i < 999 then Result := 0;                   // Zahl < 999 im Code enthalten
end;


//------------------------------------------------------------------------------
// Scanner für Compilercode (lexigrafische Analyse)
//------------------------------------------------------------------------------
procedure Scanner(Zeichen: string ;var Error: Byte);
var
  i : Integer;                                                         // Index
  Error_B,Error_Z : Byte;                                     // Fehlerzustände
begin
 i := 0;                                                    // Startwert Befehl
 repeat
  Error_B := CompareText(Zeichen,Befehl[i]);                 // Test auf Befehl
  Inc(i);                                                                // i+1
 until (Error_B = 0) OR (i > 128);       // kein Fehler oder unbekannter Befehl

 i := 0;
 repeat
  Error_Z := CompareText(Zeichen,Zahl[i]);                     // Test auf Zahl
  Inc(i)
 until (Error_Z = 0) OR (i > 255);          // kein Fehler oder unbekannte Zahl

 if (Error_B <> 0) AND (Error_Z <> 0) then Error := 1             // Auswertung
  else Error := 0;                                               // kein Fehler
end;

//------------------------------------------------------------------------------
// Syntaxtest für Compilercode
//------------------------------------------------------------------------------
procedure Syntax(Code,Adr : String; var  Error: Byte);
var
  i : Byte;                                                        // Zählindex
  Index : Byte;                                   // Position in Befehlstabelle
begin
 Error := 1;                                                   // Fehler setzen
 for i := 0 to 127 do                       // suche Position in Befehlstabelle
  if CompareText(Code,Befehl[i]) = 0 then Index := i;
  case Index of
   0..6,9,12..17,22..73,77..127 : if Adr = '' then Error := 0; // keine Adresse
   7..8,10..11,18..21,74..76 : if (Adr <> '') AND  (StrToInt(Adr) < 256) then Error := 0; // Adresse vorhanden und im Wertebereich
  end; // end Case
 temp := 1;
end;

//------------------------------------------------------------------------------
// Code aus geprüftem Quelltext erzeugen
//------------------------------------------------------------------------------
procedure Make_Code;
var
  i,k : Integer;
  j,Index,Adr : Byte;
  temp : String;
begin
 i := 0;                                          // für das komplette Programm
 k := 0;
 repeat
  for j := 0 to 127 do                      // suche Position in Befehlstabelle
   if CompareText(Prog_Dat[i,1],Befehl[j]) = 0 then
    begin
     Index := j;
     Break;                                                // Position gefunden
    end;
  CDaten_H[k] := Chr(Index);                         // Code als Byte im String
  if Prog_Dat[i,2] = '' then Adr := 0                     // wenn keine Adresse
   else Adr := StrToInt(Prog_Dat[i,2]);               // sonst Adresse als Byte
  CDaten_H[k+1] := Chr(Adr);                      // Adresse als Byte im String
  Inc(i);                                                      // PC hochzählen
  Inc(k,2);                                         // Speicherindex hochzählen
 until i > PC_max;
{
 for i := 0 to Mem_max do
   begin
     temp := temp + CDaten_H[i];
   end;
}
end;

//------------------------------------------------------------------------------
// Compiler Run-Button
//------------------------------------------------------------------------------
procedure TForm1.Button9Click(Sender: TObject);
var
  i     : Word;                                                        // Index
  Error1,Error2,Error_Lex : Byte;                                 // Fehlercode
begin
 for i := 0 to PC_max do Prog_Dat[i,1] := '';                  // alles löschen
 for i := 0 to PC_max do Prog_Dat[i,2] := '';
// Codescann ohne Syntaxprüfung in zwei Schritten (lexigrafische Analyse)
 i := 0;
 repeat                                                         // Code scannen
  // Schritt 1, Codespalte scannen
  Prog_Dat[i,1] := StringGrid2.Cells[1,i+1];                      // Code lesen
  Scanner(Prog_Dat[i,1],Error1);                                // Code scannen
  if Error1 > 0 then                                        // Fehlerbehandlung
   begin
    Button12.Enabled := false;                  // Grid überladen nicht möglich
    Application.MessageBox( PChar('unknown command in line '+ IntToStr(i)), 'Error', 16);
    StringGrid2.Col := 1;                                      // Spalte setzen
    StringGrid2.Row := i+1;                         // fehlerhafte Zeile setzen
    StringGrid2.SetFocus;                                          // Cursor ON
   end;

  // Schritt 2, Adressspalte scannen
  Prog_Dat[i,2] := StringGrid2.Cells[2,i+1];                   // Adresse lesen
  Scanner(Prog_Dat[i,2],Error2);                             // Adresse scannen
  if Error2 > 0 then                                        // Fehlerbehandlung
   begin
    Button12.Enabled := false;                  // Grid überladen nicht möglich
    Application.MessageBox( PChar('unknown command in line '+ IntToStr(i)), 'Error', 16);
    StringGrid2.Col := 2;                                      // Spalte setzen
    StringGrid2.Row := i+1;                         // fehlerhafte Zeile setzen
    StringGrid2.SetFocus;                                          // Cursor ON
   end;

  Inc(i);
  if (Error1 = 1) OR (Error2 = 1) then Error_Lex := 1                 // Fehler
   else Error_Lex := 0;                                          // kein Fehler
 until (i > PC_max) OR (Error_Lex = 1);     // wenn Fehler, Abbruch der Schleife

 // Syntaxprüfung
 if Error_Lex = 0 then                    // Syntaxprüfung wenn kein Codefehler
  begin
   i := 0;                                                       // PC auf null
   repeat
    Syntax(Prog_Dat[i,1],Prog_Dat[i,2],Error1);                   // Syntaxtest
    if Error1 = 1 then
     begin
      Button12.Enabled := false;                // Grid überladen nicht möglich
      Application.MessageBox( PChar('Syntax Error in line '+ IntToStr(i)), 'Error', 48);
      StringGrid2.Col := 2;                                    // Spalte setzen
      StringGrid2.Row := i+1;                       // fehlerhafte Zeile setzen
      StringGrid2.SetFocus;
      Exit;                                                          // Abbruch
     end;
    Inc(i);                                                              // i+1
   until i > PC_max;                                          // PC durchlaufen

   Make_Code;                                                  // Code erzeugen
   Button12.Enabled := true;                          // Grid überladen möglich
   Application.MessageBox( PChar('Code is ready'), 'Compiler', 64);

   temp := 1;
  end; // end if Error_Lex = 0
end;

//------------------------------------------------------------------------------
// Compiler New-Button
//------------------------------------------------------------------------------
procedure TForm1.Button10Click(Sender: TObject);
var
  i : Word;                                                          // Index

begin
 for i := 0 to PC_max do                           // bis ende Programmspeicher
  begin
   Prog_Dat[i,1] := '';                                 // Programmcode löschen
   Prog_Dat[i,2] := '';
   StringGrid2.Cells[0,i+1] := '';                        // PC-Counter löschen
   StringGrid2.Cells[1,i+1] := '';                              // Code löschen
   StringGrid2.Cells[2,i+1] := '';                           // Adresse löschen
  end; // for i := 0
  CDaten_H := '';
end;


//------------------------------------------------------------------------------
// Compiler Grid Action
//------------------------------------------------------------------------------
procedure TForm1.StringGrid2Click(Sender: TObject);
begin
 temp := StringGrid2.Row;
 with StringGrid2 do
  begin
   Cells[0,Row] := InttoStr(Row-1);                 // nummeriert Eingabezeilen
   Cells[Col,Row] := UpperCase(Cells[Col,Row]);    // in Großbuchstaben wandeln
  end;
end;

//------------------------------------------------------------------------------
// mögliche Compiler Zahlen (Schlüselwörter)
//------------------------------------------------------------------------------
procedure Init_Zahlen;
var i : Byte;                                                          // Index
begin
 for i := 0 to 255 do Zahl[i] := IntToStr(i);
end;

//------------------------------------------------------------------------------
// mögliche Compiler Befehle (Schlüselwörter)
//------------------------------------------------------------------------------
procedure Init_Befehle;
var i : Byte;
begin
// for i := 0 to 127 do Befehl[i] := 'FF';      // alle ungenutzen Befehle mit FF

 Befehl[0] := '';                                                        // NOP
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
 Init_Zahlen;
End.
