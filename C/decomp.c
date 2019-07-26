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

/* Funktionsprototypen */

char * get_cmd_str(unsigned code);

int needs_adress(char code);
int needs_mem_adress(char code);
int needs_param(char code);
int needs_prog_adress(char code);

static char * prepare_output_line(char *marke, char *kdo, int adresse, int ch);
void prep_marke(char * marke, int flag, int a);

void usage(char * Program);

// Ich weiss, globale Variablen sind keine gute idee
int statflag_hex_output;
int statflag_line_output;
int statflag_file_output;
int statflag_verbose_mode;
int statflag_boris4_mode;

// Braucht das Kommando eine Adresse - Zusammenfassung
int needs_adress(char code) {
char bas_code;

   // Die Index-Codes sind um 128 verschoben
   if (code < 0) 
     bas_code = code + 128;
   else 
     bas_code = code;

   return (needs_mem_adress(bas_code) + needs_prog_adress(bas_code) + needs_param(bas_code));
}


// STO und RCL sind Speicherbefehle und brauchen eine Adresse 0..31
int needs_mem_adress(char code) {
 if (code ==  7 || code == 8 || code == 18 || code == 19 || code == 20 || code == 21) return 1;
 return 0;
}

// FIX und GRD brauchen einen Parameter
int needs_param(char code) {
 // Bei boris6 sind da noch befehle dazugekommen (SFILE ...) 
 if (statflag_boris4_mode == 6) {
   if (code == 67 || code == 68 || code == 71 || code == 72) return 1;
 } else {
   if (code ==  69 || code == 112) return 1;
 }
 return 0;
}

// GOTO, GOSUB, IF*i, END sind steuerbefehle und brauchen eine Adresse von 0.255
int needs_prog_adress(char code) {
 if (statflag_boris4_mode == 4) {
    if (code == 10 || code == 11 || code == 74 || code == 75 || code == 76 || code == 126) return 1;
 }
 // boris5 hat weitere Befehle
 if (statflag_boris4_mode == 5) {
    if (code == 10 || code == 11 || code == 74 || code == 75 || code == 76 || code == 126 \
       || code == 116 || code == 117 || code == 118 || code == 119 || code == 120 || code == 121) return 1;
 }
 // boris6 hat weitere Befehle
 if (statflag_boris4_mode == 6) {
    if (code ==  10 || code ==  11 || code == 23 || code == 113 || code == 114 || code == 115 || code == 116 \
       || code == 117 || code == 118 || code == 119 || code == 120 || code == 121) return 1;
    }
 return 0;
}

// Formatieren des Markenfeldes auf 3 Dezimale mit fuehrenden Nullen
void prep_marke(char * marke, int flag, int a) {
   char * cp;
   int i;

   cp = marke;
   for(i=0;i<3;i++) {
     *cp = ' ';
     cp++;
   }
   *cp = '\0';
   if (flag || statflag_line_output) sprintf(marke, "%03d", a);   
}                

// Kommandocodes umsetzen
char * get_cmd_str(unsigned code) {

   // if (code <0 ) return (char *) NULL;  // -1 is EOF
  if (code == -1) {
     if (statflag_verbose_mode)
        fprintf(stderr, "mapping EOF %d to END\n", code);
     if (statflag_boris4_mode == 6) {
           code = 23;
     } else {
           code = 126;
     }
  }

  if (statflag_boris4_mode == 4) {
     if (code > 127) return (char *) NULL;
     if (code < 128 && strlen(kdo_4_codes[code]) > 0) return kdo_4_codes[code];
  }
  if (statflag_boris4_mode == 5) {
     if (code > 255) return (char *) NULL;
     if (code < 256 && strlen(kdo_5_codes[code]) > 0) return kdo_5_codes[code];
  }
  if (statflag_boris4_mode == 6) {
     if (code > 255) return (char *) NULL;
     if (code < 256 && strlen(kdo_6_codes[code]) > 0) return kdo_6_codes[code];
  }
  fprintf(stderr, "ERROR: code %d kann nicht uebersetzt werden\n", code);
  return (char *) NULL;
}

// Ausgabeformatierung
static char * prepare_output_line(char *marke, char *kdo, int adresse, int ch) {
   static char codeline[24];
   static char codecpy[24];
   char *cp;
   char *ccp;

   cp = codeline;
   *cp = '\0';
   if ( needs_adress(ch)) {
       // printf ("%s %s %d\t; %02x %02x\n", marke, kdo, adresse, ch, adresse);
       // boris6 schreibt einen Doppelpunkt vor die Adresse
       // 120 Loop 8 : 120
       if (statflag_boris4_mode == 6) {
          sprintf (codecpy, "%s %s", marke, kdo);
          ccp=codecpy+strlen(codecpy);
          while(ccp<codecpy+10) {
             *ccp = ' ';
             ccp++;
          }
          *ccp = '\0';
          // die Index-Kommandos sind oberhalb der 127
          if (ch > 127) {
             sprintf (codeline, "%s Ix%2d", codecpy, adresse);
          } else {
             sprintf (codeline, "%s :%3d", codecpy, adresse);
          }
       } else {
          sprintf (codeline, "%s %s %d", marke, kdo, adresse);
       }
   } else {
       // printf ("%s %s\t; %02x %02x\n", marke, kdo, ch, 0);
       sprintf (codeline, "%s %s", marke, kdo);
   }
   cp+=strlen(codeline);

   while(cp<codeline+16) {
      *cp = ' ';
      cp++;
   }
   if (statflag_hex_output) {
      sprintf(cp, "; %02x %02x", ch, adresse);
      cp += 7;
   }
   *cp = '\0';
   return codeline;
}


void usage(char * Program) {
   fprintf(stderr, "%s - Ein Kommandozeilen Disassembler fuer boris4/5/6 - Programme\n\n",Program);
   fprintf(stderr, "Bitteschoen: %s [-lxv] [-4|-5|-6] [-o outfile] Eingabedatei\n",Program);
   fprintf(stderr, "     -l          Alle Zeilennummern ausgeben (default: nur als Marken benutzte)\n");
   fprintf(stderr, "     -v          geschwaetziger modus\n");
   fprintf(stderr, "     -4          boris4 - modus \n");
   fprintf(stderr, "     -5          boris5 - modus \n");
   fprintf(stderr, "     -6          boris6 (Voyager) - modus (default)\n");
   fprintf(stderr, "     -x          Hexcode als Kommentar hinzufuegen\n");
   fprintf(stderr, "     -o Datei    Ausgabe in eine Datei (default: stdout)\n");
}

int main(int argc, char * argv[]) {
     FILE* file_in;
     FILE* file_out;
     int c, i, a;
     int ch;
     int end_flag;

     int adresse;
     char * kdo;

     int used_mem[32];
     int used_prog[256];

     char marke[4];

     char *cp;

     int index;

     char infile[256];
     char outfile[256];

     statflag_hex_output = 0;
     statflag_file_output = 0;
     statflag_line_output = 0;
     statflag_verbose_mode = 0;
     statflag_boris4_mode = 6;
     
     opterr = 0;
     end_flag = 0;

     while ((c = getopt (argc, argv, (const char *) "lxhv456o")) != -1) {
        switch (c)
          {
          case 'x':
            statflag_hex_output = 1;
            break;
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
          case 'o':
            statflag_file_output = 1;
            break;
          case 'l':
            statflag_line_output = 1;
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

      if (statflag_verbose_mode) {
         fprintf (stderr, "statflag_hex_output = %d, statflag_file_output = %d\n", statflag_hex_output, statflag_file_output);
         if (statflag_boris4_mode == 4) {
            fprintf (stderr, "Boris-4 modus\n");
         }
         if (statflag_boris4_mode == 5) {
            fprintf (stderr, "Boris-5 modus\n");
         }
         if (statflag_boris4_mode == 6) {
            fprintf (stderr, "Boris-6 (Voyager) modus\n");
         }
         fprintf (stderr, "optind = %d, argc = %d\n", optind, argc);

         for (index = optind; index < argc; index++) {
           fprintf (stderr, "Non-option argument %s\n", argv[index]);
         }
      }

      index = optind;

      if (index >= argc) {
          fprintf (stderr, "Parameterfehler\n");
          usage(argv[0]);
          return 1;
      }

      if (statflag_file_output) {
        strcpy(outfile, argv[index]);
        index++;
        if (index >= argc) {
          fprintf (stderr, "Parameterfehler\n");
          usage(argv[0]);
          return 1;
        }
        strcpy(infile, argv[index]);
      } else {
        strcpy(infile, argv[index]);
      }

      if (statflag_verbose_mode)
         fprintf(stderr, "Files: Input: >%s< Output: >%s<\n", infile, outfile);

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

         // Erst mal nur nach Adressen suchen
         while (ch != EOF) {
            ch = fgetc(file_in);
            adresse = fgetc(file_in); 
            // kdo =  get_cmd_str((unsigned) ch);

            // if (statflag_verbose_mode)
            //     fprintf (stderr, "translated code %d to kdo >%s<\n", ch, kdo);

            if (needs_mem_adress(ch)) used_mem[adresse] = 1;
            if (needs_prog_adress(ch)) used_prog[adresse] = 1;
         }
            
         rewind (file_in);
         ch = 0;

         fprintf (file_out, "# Programm %s\n", (const char *)infile);
         fprintf (file_out, "# Verwendete Speicher: ");
         if (statflag_verbose_mode)
            fprintf (stderr, "Verwendete Speicher: ");

         for(i=0;i<32;i++) {
            if (used_mem[i]) {
              fprintf (file_out, "%d ", i);
              if (statflag_verbose_mode)
                 fprintf (stderr, "%d ", i);
            }
         }
         fprintf (file_out, "\n");
         if (statflag_verbose_mode)
               fprintf (stderr, "\n");

         while (ch != EOF && end_flag == 0) {
            ch = fgetc(file_in);
            adresse = fgetc(file_in); 
            if (statflag_boris4_mode == 6 && ch > 127) {
               kdo =  get_cmd_str((unsigned) ch-128);
            } else {
               kdo =  get_cmd_str((unsigned) ch);
            }

            if (statflag_verbose_mode)
                 fprintf (stderr, "translated code %d to kdo >%s<\n", ch, kdo);

            if (statflag_boris4_mode == 6 && strcmp(kdo, "END") == 0) {
               end_flag = 1;
            }

            if (needs_mem_adress(ch)) used_mem[adresse] = 1;
            prep_marke(marke, used_prog[a], a);                
            if (((ch != EOF && adresse != EOF)  || end_flag == 1) && kdo != NULL) {
               cp =  prepare_output_line(marke, kdo, adresse, ch);
               // Bei Boris6 haben wir an der ersten Position ein Leerzeichen
               if (statflag_boris4_mode == 6) {
                  fprintf(file_out, " %s\n", cp);
               } else {
                  fprintf(file_out, " %s\n", cp);
               }
               a++; 
               if (statflag_verbose_mode)
                  fprintf (stderr, ".");
            }
         }

         if (statflag_verbose_mode)
                  fprintf (stderr, "\n%d Zeilen\n",a);

         fclose(file_in);
         if (statflag_file_output) {
            fclose(file_out);
         }
     }
     if (statflag_verbose_mode)
              fprintf (stderr, "OK\n");

     return 0;
}

