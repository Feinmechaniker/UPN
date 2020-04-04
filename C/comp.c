/* ****************************************************************************
*
* Boris M
* (One of the last UPN-Taschenrechner)
* Command line tools to assemble / disassemble program files
*
* Copyright (c) 2019, 2020  g.dargel <srswift@arcor.de> www.srswift.de
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

#define PRG_VERSION    "1.1"

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

int lbnr = 0; // Index im Labelarray, anzahl gelesener Labels
int lbl_line[100]; // Labelarray Zeilennummer
int lbl_nr[100];   // Labelarray symb. Name


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

   if (statflag_boris4_mode == 4) {
       if (bas_code ==  7 || bas_code == 8 || bas_code == 10 || bas_code == 11 || bas_code == 18 || bas_code == 19 || bas_code == 20 \
                      || bas_code == 21 || bas_code == 69 || bas_code == 74 || bas_code == 75 || bas_code == 76 || bas_code == 112 || bas_code == 126) return 1;
   } 

   if (statflag_boris4_mode == 5) {
       if (bas_code == 7 || bas_code == 8 || bas_code == 10 || bas_code == 11 || bas_code == 18 || bas_code == 19 || bas_code == 20 \
                      || bas_code == 21 || bas_code == 69 || bas_code == 74 || bas_code == 75 || bas_code == 76 || bas_code == 112 || bas_code == 116 \
                      || bas_code == 117 || bas_code == 118 || bas_code == 119 || bas_code == 120 || bas_code == 121 || bas_code == 126) return 1;
   }

   if (statflag_boris4_mode == 6) {
       if (bas_code ==   7 || bas_code ==   8 || bas_code ==  10 || bas_code ==  11 || bas_code ==  18 \
              || bas_code ==  19 || bas_code ==  20 || bas_code ==  21 || bas_code ==  67 || bas_code ==  68 \
              || bas_code ==  71 || bas_code ==  72 || bas_code == 113 || bas_code == 114 || bas_code == 115 \
              || bas_code == 116 || bas_code == 117 || bas_code == 118 || bas_code == 119 || bas_code == 120 \
              || bas_code == 121 ) return 1;
   }
   return 0;
}


// --------------------------------------------------
// Kommandocodes umsetzen
// Input ist ein Pointer auf den Kommandostring, der aber Leerzeichen enthalten kann
// Wenn er mindestens ein Leerzeichen hat, enthaelt er auch eine Adresse.
// Die Adresse muss vor dem Zeichenkettenvergleich weggetrimmt werden
// return 255 = Fehler!
unsigned short get_cmd_cde(char * code) {
  int i;
  char * last_space;
  char wrk_kdo[256];
  char cmp_kdo[256];
  char *cp;
  char *ccp;

  if (statflag_verbose_mode)
     fprintf (stderr, "get_cmd_cde = >%s<\n", code);

  strcpy(wrk_kdo, code);

  last_space = strrchr(wrk_kdo, ' '); 

  if (last_space != NULL) {
     // trimmen
    while (isWspace(*last_space) && last_space > wrk_kdo) {
       *last_space = '\0';
       last_space--;
    }
  }

  if (statflag_verbose_mode)
     fprintf (stderr, "get_cmd_cde wrk_kdo = >%s<\n", wrk_kdo);

  if (last_space != NULL) {
     // trimmen
    while (isWspace(*last_space) && last_space > wrk_kdo) {
       *last_space = '\0';
       last_space--;
    }
  }

  if (statflag_verbose_mode)
     fprintf (stderr, "get_cmd_cde trim = >%s<\n", wrk_kdo);

  if (statflag_boris4_mode == 4) {
     for(i=0; i<128; i++) {
        if (!strcmp(wrk_kdo, kdo_4_codes[i])) return i;
     }
  } 


  if (statflag_boris4_mode == 5) {
     for(i=0; i<256; i++) {
        if (!strcmp(wrk_kdo, kdo_5_codes[i])) return i;
     }
  }

  if (statflag_boris4_mode == 6) {
     for(i=0; i<256; i++) {
        // toupper
        for (cp = kdo_6_codes[i], ccp=cmp_kdo; *cp != '\0' && *cp != ';'; cp++, ccp++) {
           *ccp = toupper(*cp);
        }
        *ccp = '\0';

        if (!strcmp(wrk_kdo, cmp_kdo)) return i;
     }
  }

  return 255;
}

// Codezeile ein wenig aufbereiten
// trimright
// toupper

void clean_code_line(char *line) {
   char * cp;
   char * ccp;

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
   // if (statflag_boris4_mode == 6 || statflag_boris4_mode == 5) {
       // Boris6 hat vorn mglw ein Leerzeichen, das kann weg!
       cp = line;
       if (isWspace (*cp)) {
          ccp = cp+1;
          while (*ccp != '\0') {
            *cp = *ccp;
            cp++; ccp++;
          }
          *cp = '\0'; 
       }
       // Boris6 hat gelegentlich ein : vor der Adresse, das loeschen wir
       cp = line;
       while (*cp != '\0') {
          if (*cp == ':') *cp = ' ';
          cp++; 
       }
   // }
}


void usage(char * Program) {
   fprintf(stderr, "%s - v%s - Ein Kommandozeilen Assembler fuer boris4/5/6 - Programme\n\n",Program, PRG_VERSION);
   fprintf(stderr, "Bitteschoen: %s [-v] [-n] [-4|-5|-6] [-s startadresse] [-o outfile] Eingabedatei\n",Program);
   fprintf(stderr, "     -n          Datei mit NOP auffuellen\n");
   fprintf(stderr, "     -v          geschwaetziger modus\n");
   fprintf(stderr, "     -4          boris4 - modus\n");
   fprintf(stderr, "     -5          boris5 - modus\n");
   fprintf(stderr, "     -6          boris6 (voyager) - modus (default)\n");
   fprintf(stderr, "     -s Adresse  Startadresse des Programms (default: 0)\n");
   fprintf(stderr, "     -o Datei    Ausgabe in eine Datei (default: stdout)\n");
}

// Adresse bestimmen, entweder aus dem String 3stellige Zahl direkt lesen,
// oder aus der Label-Tabelle lesen,
// Im Fehlerfall: Return -1
int translate_label(char *s) {
    char *p;
    int scan_lbl;
    int i;

    static int adresse;

    adresse = -1;

    if (*s == 'l' || *s == 'L') {
       // Symbolische Adresse, aus Tabelle heraussuchen
       p = s+1;
       i = sscanf(p, "%d", &scan_lbl);
       if (i == 1) {
          for (i=0; i<lbnr; i++) {
              if (lbl_nr[i] == scan_lbl)
                 adresse = lbl_line[i];
          }
       }
    } else {
       i = sscanf(s, "%d", &scan_lbl);
       if (i == 1 && scan_lbl < 255) 
          adresse = scan_lbl;
    }
    if (adresse < 0) adresse = -1;

    if (statflag_verbose_mode) {
         fprintf (stderr, "Adresse decodiert >%s< - %d\n", s, adresse);
    }
    return (adresse);
}


int main(int argc, char * argv[]) {
     FILE* file_in;
     FILE* file_out;
     char line[256];
     // char kdo[8];
     char *s;
     char *cp;
     int c, i, a;

     int errstate;

     int startadr;
     char startadr_str[256];

     int adresse;
     int zeile;

     char *lb;
     int dlabel = 0; // gelesenes Label

     unsigned short code;

     int index;
     
     char infile[256];
     char outfile[256];

     opterr = 0;

     statflag_file_output = 0;
     statflag_verbose_mode = 0;
     statflag_fill_nop_mode = 0;
     statflag_boris4_mode = 6;
     startadr_str[0] = '\0';
     startadr = 0;

     s = line;

     while ((c = getopt (argc, argv, (const char *) "nh456vo:s:")) != -1) {
        switch (c)
          {
          case 'v':
            statflag_verbose_mode = 1;
            break;
          case '4':
            statflag_boris4_mode = 4;
            break;
          case '5':
            statflag_boris4_mode = 5;
            break;
          case '6':
            statflag_boris4_mode = 6;
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

         if (statflag_boris4_mode == 4) {
            fprintf (stderr, "Boris-4 modus\n");
         }

         if (statflag_boris4_mode == 5) {
            fprintf (stderr, "Boris-5 modus\n");
         }

         if (statflag_boris4_mode == 6) {
            fprintf (stderr, "Boris-6 (Voyager) modus\n");
         }

         fprintf(stderr, "Files: Input: >%s< Output: >%s<\n", infile, outfile);
         fprintf(stderr, "Startadresse: >%s< %d\n", startadr_str, startadr);

         for (index = optind; index < argc; index++) {
           fprintf (stderr, "Non-option argument %s\n", argv[index]);
         }
      }

      if (statflag_boris4_mode == 4) {
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
         lbnr = 0;
         errstate = 0; // nur wenn der pre-Lauf OK ist, machen wir weiter

         // Erst ein mal ein Pre-Lauf ueber die Datei, wir sammeln die Label 
         // und bauen eine Liste der symbolischen Adressen

         while (fgets(s, 255, file_in) != NULL) {
            if (!is_comment(line)) {
               clean_code_line(line);
               if (strlen(line) > 0) {
                  if (!isWspace (line[0])){
                     // wir haben vorn eine Zeilennummer oder symb. Adresse
                     if (line[0] == 'l' || line[0] == 'L') {
                        lb = &line[1];
                        // symbolische Adresse, merken!
                        i = sscanf(lb, "%d", &dlabel);
                        if (i == 1) {
                            // Bereits gelesens Labels auf Duplikate prüfen
                            for (i=0; i<lbnr; i++) {
                               if (lbl_nr[i] == dlabel) {
                                   fprintf(stderr, "ERROR: Doppeltes Label %d in Zeile %d  / %d\n", dlabel, lbl_line[i], a);
                                   errstate = 1;
                               }
                            }
                        } else {
                            fprintf(stderr, "ERROR: Lesefehler label in Zeile (%d) >%s<\n", a, line);
                            errstate = 1;
                        }

                        if (errstate == 0) {
                           lbl_nr[lbnr] = dlabel;
                           lbl_line[lbnr] = a;

                           lbnr++;
                           if (lbnr > 99) {
                               fprintf(stderr, "ERROR: Zu viele Labels (%d) in Zeile (%d)\n", lbnr, a);
                               errstate = 1;
                           }
                        }
                     }
                  }
               }
               a++;
            }
         }

         a = startadr;

         if (errstate == 0) {
            rewind (file_in);
            // printf("%c%c", 170, 83);
            while (fgets(s, 255, file_in) != NULL) {
               if (!is_comment(line)) {
                  clean_code_line(line);
                  if (statflag_verbose_mode)
                       fprintf (stderr, "cleaned code line >%s<\n", line);

                  if (strlen(line) > 0) {
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
                        // i = sscanf(s, "%d", &zeile);
                        zeile = translate_label(s);
                        if (zeile >= 0) i=1;
                        // Fehlerbehandlung bzw Markenverschiebung
                        if (a != zeile || a == -1) {
                            fprintf(stderr, "WARNING: Adressabweichung in Zeile %d (%d)\n", a, zeile);
                            if (a < zeile) {
                               while (a < zeile) {
                                 if (errstate == 0) 
                                    fprintf(file_out, "%c%c", 0, 0);
                                 a++;
                               }
                            } else {
                               fprintf(stderr, "ERROR: Adressabweichung in Zeile %d (%d) nicht korrigierbar\n", a, zeile);
                               errstate = 1;
                            }
                        }
                        // vorspulen bis zum ersten "Nicht-Leerzeichen hinter der Zeilennummer"
                        cp = line;
                        while ((isWspace(*cp) == 0) && *cp != '\0') cp++;
                        while (isWspace(*cp) && *cp != '\0') cp++;
                     }
                     
                     if (statflag_verbose_mode)
                          fprintf (stderr, "code line after adress >%s<\n", cp);
                     a++;
                     code = get_cmd_cde(cp);
                     
                     if (code == 255) {
                            fprintf(stderr, "ERROR in Zeile %d (%d) : Kommando >%s< kann nicht uebersetzt werden\n", a, zeile, cp);
                            errstate = 1;
                     } else {
                        if (statflag_verbose_mode)
                           fprintf (stderr, "Command >%s< translated into code = %d\n", cp, code);
                        i++;

                        if (!needs_adress(code)) {
                           i++;
                           adresse = 0;
                        } else {
                           // Adresse Lesen
                           while (*cp != '\0') cp++;
                           cp--;
                           while ((isWspace(*cp) == 0)) cp--;
                           // Boris6 hat eine enge formatierung des Ix
                           if (statflag_boris4_mode == 6 && *(++cp) == 'I') {
                              cp+=2;
                              code += 128;
                           }
                           // i += sscanf(cp, "%d", &adresse);
                           while ((isWspace(*cp) && *cp != '\0')) cp++;
                           adresse = translate_label(cp);
                           if (adresse >= 0) i++;
                        }

                        if (i != 3) {
                           fprintf(stderr, "ERROR: Parameterfehler >%s< %d\n", line, i);
                           errstate = 1;
                        } else {
                           if (errstate == 0) 
                              fprintf(file_out, "%c%c", code, (char) adresse);
                           if (statflag_verbose_mode)
                              fprintf (stderr, ".");
                        }
                     }
                  }
               }
            }

            // END Marke schreiben
            if (statflag_boris4_mode == 6) {
               if (a < max_prg && code != 23) {
                  fprintf(file_out, "%c%c", 23, a);
                  a++;
               }
            } else {
               if (a < max_prg && code != 126) {
                  fprintf(file_out, "%c%c", 126, a);
                  a++;
               }
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
         }

         fclose(file_in);

         // gelesene symbolischen Labels ausgeben

         if (statflag_verbose_mode && lbnr > 0) {
            fprintf(stderr, "\nSymbolische Programmspeicher-Adressen : \n");
            for (i=0; i<lbnr; i++) {
               fprintf(stderr, "   L%d -> %d\n", lbl_nr[i], lbl_line[i]);
            }
         }

         if (statflag_file_output) {
            fclose(file_out);
         }
     }
     if (statflag_verbose_mode)
              fprintf (stderr, "OK\n");

     return 0;
}
