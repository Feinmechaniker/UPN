/* ****************************************************************************
*
* Boris M
* (One of the last UPN-Taschenrechner)
* Command line tools to assemble / disassemble program files
*
* Copyright (c) 2019 g.dargel <srswift@arcor.de> www.srswift.de
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
* See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program. If not, see <http://www.gnu.org/licenses/>.
*
* **************************************************************************** */

#include "boris.h"

char * get_cmd_str(char code);
int needs_param(char code);
int needs_adress(char code);
int needs_mem_adress(char code);
int needs_prog_adress(char code);
void prep_marke(char * marke, int flag, int a);                

int needs_adress(char code) {
 return (needs_mem_adress(code) + needs_prog_adress(code) + needs_param(code));
}

// STO und RCL sind Speicherbefehle und brauchen eine Adresse 0..31
int needs_mem_adress(char code) {
 if (code ==  7 || code == 8) return 1;
 return 0;
}

// FIX und GRD brauchen einen Parameter
int needs_param(char code) {
 if (code ==  69 || code == 112) return 1;
 return 0;
}

// GOTO, GOSUB, IF* sind steuerbefehle und brauchen eine Adresse von 0.255
int needs_prog_adress(char code) {
 if (code == 10 || code == 11 || code == 74 || code == 75 || code == 76) return 1;
 return 0;
}


void prep_marke(char * marke, int flag, int a) {
   char * cp;
   int i;

   cp = marke;
   for(i=0;i<3;i++) {
     *cp = ' ';
     cp++;
   }
   *cp = '\0';
   if (flag) sprintf(marke, "%03d", a);   
}                

// Kommandocodes umsetzen
char * get_cmd_str(char code) {
  if (code > 127 || code < 0) return (char *) NULL;
  if (code < 128 && strlen(kdo_codes[code]) > 0) return kdo_codes[code];
  return (char *) NULL;
}

void main(int argc, char ** argv[])
{
     FILE* file;
     int i, a;
     int ch;

     int adresse;
     char * kdo;

     int used_mem[32];
     int used_prog[256];

     char marke[4];

     // Wir merken uns beim einlesen die verwendeten Speicher / Programmzeilen um dann spaeter 
     // nur die Marken schreiben zu muessen, die wirklich verwendet werden
     // Vorher muessen wir das ganze aber loeschen
    
     for(i=0;i<32;i++) {
        used_mem[i] = 0;
     }
     for(i=0;i<256;i++) {
        used_prog[i] = 0;
     }

     a = 0;
     ch = 0;
     if(argc!=2) {
         printf("Bitteschoen: %s <binaerdatei> > <sourcedatei>\n",argv[0]);
     } else {
         file=fopen((const char *)argv[1], "r"); 
         if(file==NULL)
             printf("Fehler beim Oeffnen der Datei");
          else {
             // Erst mal nur nach Adressen suchen
             while (ch != EOF) {
                ch = fgetc(file);
                adresse = fgetc(file); 
                kdo =  get_cmd_str((char) ch);
                if (needs_mem_adress(ch)) used_mem[adresse] = 1;
                if (needs_prog_adress(ch)) used_prog[adresse] = 1;
             }
                
             rewind (file);
             ch = 0;

             printf ("# Programm %s\n", (const char *)argv[1]);
             printf ("# Verwendete Speicher: ");
             for(i=0;i<32;i++) {
                if (used_mem[i]) printf ("%d ", i);
             }
             printf ("\n");

             while (ch != EOF) {
                ch = fgetc(file);
                adresse = fgetc(file); 
                kdo =  get_cmd_str((char) ch);
                if (needs_mem_adress(ch)) used_mem[adresse] = 1;
                prep_marke(marke, used_prog[a], a);                
                if (ch != EOF && adresse != EOF && kdo != NULL) {
                   if ( needs_adress(ch)) {
                      printf ("%s %s %d\n", marke, kdo, adresse);
                   } else {
                      printf ("%s %s\n", marke, kdo);
                   }
                   a++; 
                }
             }

             fclose(file);
         }
     }
}


