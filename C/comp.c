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

unsigned short get_cmd_cde(char * code);
int needs_adress(char code);


// --------------------------------------------------
// test if char is a whitespace
int isWspace (char p_zeichen)  // IN: char to check
{
  if ( (p_zeichen == ' ') || 
       (p_zeichen == '\t') || 
       (p_zeichen == '\r') || 
       (p_zeichen == '\f') || 
       (p_zeichen == '\n') ) {
    return (1);
  } else {
    return (0);
  }
}



// --------------------------------------------------
// Eine Zeile, die nur aus Whitespaces enthaelt, ist eine Leerzeile
int is_empty_line(char *line) {
   char *p;
   for (p=line; *p != '\0'; p++) {
     if (!isWspace(*p)) {
        if (*p == '\0') return 1;
     }
   }
   return(0);
}


// --------------------------------------------------
// Eine Zeile, die mit einem # beginnt, ist eine Kommentarzeile. Fuehrende whitespaces stoeren nicht
int is_comment(char *line) {
   char *p;
   for (p=line; *p != '\0'; p++) {
     if (!isWspace(*p)) {
        if (*p == '#') return 1;
     }
   }
   return(0);
}


// --------------------------------------------------
// Welche Kommandos brauchen eine Adresse ?
int needs_adress(char code) {
 if (code ==  7 || code == 8 || code == 10 || code == 11 || code == 18 || code == 19 || code == 20 || code == 21 || code == 69 || code == 74 || code == 75 || code == 76 || code == 112) return 1;
 return 0;
}

// --------------------------------------------------
// Kommandocodes umsetzen
unsigned short get_cmd_cde(char * code) {
  int i;

  for(i=0;i<128;i++) {
     if (!strcmp(code, kdo_codes[i])) return i;
  }
  fprintf(stderr, "ERROR: Kommando >%s< kann nicht uebersetzt werden\n", code);
  return 255;
}


void main(int argc, char ** argv[]) {
     FILE* file;
     char line[256];
     char kdo[8];
     char *s;
     int i, a;
     int ch;

     int adresse;
     int zeile;

     unsigned short code;
     
     s = line;
     a = 0;
     ch = 0;
     // Nur mit Argument starten 
     if(argc!=2) {
         fprintf(stderr, "Bittschoen : %s <sourcefile> > <binaerfile> \n",argv[0]);
     } else {
         file=fopen((const char *)argv[1], "r");
         if(file==NULL)
             fprintf(stderr, "ERROR: Fehler beim Oeffnen der Datei %s\n", argv[1]);
          else {
             while (fgets(s, 255, file) != NULL) {
                if (!is_comment(line)) {
                   if (isWspace (line[0])){
                      i = sscanf(s, " %s %d", &kdo, &adresse);
                      i++;
                   } else {
                      i = sscanf(s, "%d %s %d", &zeile, &kdo, &adresse);
                   }
                   
                   a++;
                   code = get_cmd_cde(kdo);
                   if (!needs_adress(code)) {
                      i++;
                      adresse = 0;
                   }
                   if (i != 3) {
                      fprintf(stderr, "ERROR: Parameterfehler >%s< \n", line);
                   } else {
                      printf("%c%c", code, (char) adresse);
                   }
                }
             }

             while (a < 100) {
                   printf("%c%c", 0, 0);
                   a++;
             }

             fclose(file);
         }
     }
}


