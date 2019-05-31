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

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#include "boris.h"

// Ich weiss, globale Variablen sind keine gute idee
int statflag_file_output;
int statflag_verbose_mode;
int statflag_fill_nop_mode;
int statflag_boris4_mode;
int max_prg;


/* Funktionsprototypen */

unsigned short get_cmd_cde(char * code);

int is_comment(char *line);
int is_empty_line(char *line);
int isWspace (char p_zeichen);

int main(int argc, char * argv[]);
int needs_adress(char code);

void usage(char * Program);

// --------------------------------------------------
// test if char is a whitespace
int isWspace (char p_zeichen)  // IN: char to check
{
  if ( (p_zeichen == ' ') || 
       (p_zeichen == '@') || 
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

char bas_code;

   // Die Index-codes sind um 128 verschoben
   if (code < 0)
      bas_code = code+128;
   else
      bas_code = code;

   if (statflag_boris4_mode) {
       if (bas_code ==  7 || bas_code == 8 || bas_code == 10 || bas_code == 11 || bas_code == 18 || bas_code == 19 || bas_code == 20 \
                      || bas_code == 21 || bas_code == 69 || bas_code == 74 || bas_code == 75 || bas_code == 76 || bas_code == 112 || bas_code == 126) return 1;
   } else {
       if (bas_code == 7 || bas_code == 8 || bas_code == 10 || bas_code == 11 || bas_code == 18 || bas_code == 19 || bas_code == 20 \
                      || bas_code == 21 || bas_code == 69 || bas_code == 74 || bas_code == 75 || bas_code == 76 || bas_code == 112 || bas_code == 116 \
                      || bas_code == 117 || bas_code == 118 || bas_code == 119 || bas_code == 120 || bas_code == 121 || bas_code == 126) return 1;
   }
   return 0;
}


// --------------------------------------------------
// Kommandocodes umsetzen
// Input ist ein Pointer auf den Kommandostring, der aber Leerzeichen enthalten kann
// Wenn er mindestens ein Leerzeichen hat, enthaelt er auch eine Adresse.
// Die Adresse muss vor dem Zeichenkettenvergleich weggetrimmt werden
unsigned short get_cmd_cde(char * code) {
  int i;
  char * last_space;
  char wrk_kdo[256];

  strcpy(wrk_kdo, code);

  last_space = strrchr(wrk_kdo, ' '); 

  if (last_space != NULL) {
     // trimmen
    while (isWspace(*last_space) && last_space > wrk_kdo) {
       *last_space = '\0';
       last_space--;
    }
  }

  if (statflag_boris4_mode) {
     for(i=0; i<128; i++) {
        if (!strcmp(wrk_kdo, kdo_4_codes[i])) return i;
     }
  } else {
     for(i=0; i<256; i++) {
        if (!strcmp(wrk_kdo, kdo_5_codes[i])) return i;
     }
  }

  fprintf(stderr, "ERROR: Kommando >%s< kann nicht uebersetzt werden\n", code);

  return 255;
}

// Codezeile ein wenig aufbereiten
// trimright
// toupper

void clean_code_line(char *line) {
   char * cp;

   // toupper
   for (cp = line; *cp != '\0' && *cp != ';'; cp++) {
      *cp = toupper(*cp);
   }

   // Hinter einem ; kann alles abgeschnitten werden
   if (*cp == ';') *cp = '\0';

   // Trimmen
   cp--;
   while (isWspace (*cp)) {
      *cp = '\0';
      cp--;
   }

}


void usage(char * Program) {
   fprintf(stderr, "%s - Ein Kommandozeilen Assembler fuer boris4/5 - Programme\n\n",Program);
   fprintf(stderr, "Bitteschoen: %s [-v] [-n] [-4] [-s startadresse] [-o outfile] Eingabedatei\n",Program);
   fprintf(stderr, "     -n          Datei mit NOP auffuellen\n");
   fprintf(stderr, "     -v          geschwaetziger modus\n");
   fprintf(stderr, "     -4          boris4 - modus (default: boris5)\n");
   fprintf(stderr, "     -s Adresse  Startadresse des Programms (default: 0)\n");
   fprintf(stderr, "     -o Datei    Ausgabe in eine Datei (default: stdout)\n");
}


int main(int argc, char * argv[]) {
     FILE* file_in;
     FILE* file_out;
     char line[256];
     // char kdo[8];
     char *s;
     char *cp;
     int c, i, a;

     int startadr;
     char startadr_str[256];

     int adresse;
     int zeile;

     unsigned short code;

     int index;
     
     char infile[256];
     char outfile[256];

     opterr = 0;

     statflag_file_output = 0;
     statflag_verbose_mode = 0;
     statflag_fill_nop_mode = 0;
     statflag_boris4_mode = 0;
     startadr_str[0] = '\0';
     startadr = 0;

     s = line;

     while ((c = getopt (argc, argv, (const char *) "nh4vo:s:")) != -1) {
        switch (c)
          {
          case 'v':
            statflag_verbose_mode = 1;
            break;
          case '4':
            statflag_boris4_mode = 1;
            break;
          case 'n':
            statflag_fill_nop_mode = 1;
            break;
          case 'o':
            statflag_file_output = 1;
            if (strlen(optarg) < 255) {
                strcpy(outfile, optarg);
            } else {
                fprintf(stderr, "Parameterfehler Eingabedateiname -> %s\n",optarg);
                return 1;
            }
            break;
          case 's': // Startadresse folgt
            if (strlen(optarg) < 255) {
                strcpy(startadr_str, optarg);
                i = sscanf(startadr_str, "%d", &startadr);
                if (i < 1 || startadr > 255) {
                   fprintf(stderr, "Parameterfehler Startadresse %s -> %d\n", startadr_str, startadr);
                }
            } else {
                fprintf(stderr, "Parameterfehler Startadresse -> %s\n",optarg);
                return 1;
            }
            break;
          case 'h':
            usage(argv[0]);
            return 1;
            break;
          case '?':
            if (isprint (optopt))
              fprintf (stderr, "Unbekannte Option `-%c'.\n", optopt);
            return 1;
          default:
            abort ();
          }
      }

      index = optind;

      if (index >= argc) {
          fprintf (stderr, "Aufruffehler : Parameter\n");
          usage(argv[0]);
          return 1;
      }
      strcpy(infile, argv[index]);

      if (statflag_verbose_mode) {
         fprintf (stderr, "statflag_file_output = %d\n", statflag_file_output);

         if (statflag_boris4_mode) {
            fprintf (stderr, "Boris-4 modus\n");
         } else {
            fprintf (stderr, "Boris-5 modus\n");
         }

         fprintf(stderr, "Files: Input: >%s< Output: >%s<\n", infile, outfile);
         fprintf(stderr, "Startadresse: >%s< %d\n", startadr_str, startadr);

         for (index = optind; index < argc; index++) {
           fprintf (stderr, "Non-option argument %s\n", argv[index]);
         }
      }

      if (statflag_boris4_mode) {
         max_prg = 100;
      } else {
         max_prg = 255;
      }

     if(strlen(infile) == 0) {
         usage(argv[0]);
     } else {
         file_in=fopen((const char *) infile, "r"); 
         if (file_in==NULL) {
             fprintf(stderr, "ERROR: Fehler beim Oeffnen der Datei %s\n", infile);
             return 1;
         }

         if (statflag_file_output) {
            file_out=fopen((const char *) outfile, "w"); 
            if(file_out==NULL) {
                fprintf(stderr, "ERROR: Fehler beim Oeffnen der Datei %s\n", outfile);
                return 1;
            }
         } else {
            file_out=stdout;
         }

#ifdef _WIN32
         // _setmode(_fileno(stdout), _O_BINARY);
         _setmode(_fileno(file_out), _O_BINARY);
#endif

         a = startadr;

         // printf("%c%c", 170, 83);
         while (fgets(s, 255, file_in) != NULL) {
            if (!is_comment(line)) {
               clean_code_line(line);
               if (isWspace (line[0])){
                  // wir haben vorn keine Zeilennummer
                  // i = sscanf(s, "%[^@]@%d", kdo, &adresse);
                  zeile = 0;
                  // vorspulen bis zum ersten "Nicht-Leerzeichen"
                  cp = line;
                  while (isWspace(*cp) && *cp != '\0') cp++;
                  i = 1;
               } else {
                  // wir haben vorn eine Zeilennummer
                  // i = sscanf(s, "%d%[^@]@%d", &zeile, kdo, &adresse);
                  i = sscanf(s, "%d", &zeile);
                  // Fehlerbehandlung bzw Markenverschiebung
                  if (a != zeile) {
                      fprintf(stderr, "WARNING: Adressabweichung in Zeile %d (%d)\n", a, zeile);
                      if (a < zeile) {
                         while (a < zeile) {
                           fprintf(file_out, "%c%c", 0, 0);
                           a++;
                         }
                      } else {
                         fprintf(stderr, "ERROR: Adressabweichung in Zeile %d (%d) nicht korrigierbar\n", a, zeile);
                      }
                  }
                  // vorspulen bis zum ersten "Nicht-Leerzeichen hinter der Zeilennummer"
                  cp = line;
                  while ((isWspace(*cp) == 0) && *cp != '\0') cp++;
                  while (isWspace(*cp) && *cp != '\0') cp++;
               }
               
               a++;
               code = get_cmd_cde(cp);
               // if (statflag_verbose_mode)
               //    fprintf (stderr, "Command >%s< translated into code = %d\n", cp, code);

               i++;

               if (!needs_adress(code)) {
                  i++;
                  adresse = 0;
               } else {
                  // Adresse Lesen
                  while (*cp != '\0') cp++;
                  cp--;
                  while ((isWspace(*cp) == 0)) cp--;
                  i += sscanf(cp, "%d", &adresse);
               }

               if (i != 3) {
                  fprintf(stderr, "ERROR: Parameterfehler >%s< \n", line);
               } else {
                  fprintf(file_out, "%c%c", code, (char) adresse);
                  if (statflag_verbose_mode)
                     fprintf (stderr, ".");
               }
            }
         }

         // END Marke schreiben
         if (a < max_prg && code != 126) {
               fprintf(file_out, "%c%c", 126, a);
               a++;
         }

         if (statflag_verbose_mode)
                  fprintf (stderr, "\n%d Zeilen\n",a-startadr);

         if (statflag_fill_nop_mode) {
            while (a < max_prg) {
                  fprintf(file_out, "%c%c", 0, 0);
                  a++;
            }
            if (statflag_verbose_mode)
                  fprintf (stderr, "Auffuellen mit NOP bis %d\n",a);
         }

         fclose(file_in);
         if (statflag_file_output) {
            fclose(file_out);
         }
     }
     if (statflag_verbose_mode)
              fprintf (stderr, "OK\n");

     return 0;
}

