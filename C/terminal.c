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
#include <windows.h>
#endif

#include "boris.h"

int statflag_file_inout;
int statflag_verbose_mode;

#ifdef _WIN32
#define SERIALPORT HANDLE
#else
#define SERIALPORT int
#endif

/* =================================================================
// Oeffnet seriellen Port
// Gibt das Filehandle zurueck oder -1 bei Fehler
//
// RS232-Parameter
// - 9600 baud
// - 8 bits/byte
// - no parity
// - no handshake
// - 1 stop bit
==================================================================== */
#ifdef _WIN32

// ====================================
// Windows Variante
// ====================================
SERIALPORT open_port(const char * device) { 

   HANDLE hComm;
   DCB    dcb;
	
   hComm = CreateFile("\\\\.\\COM1", 
            GENERIC_READ | GENERIC_WRITE, 
            0, 
            NULL,
            OPEN_EXISTING, 
            0, 
            NULL);
            
   if (hComm == INVALID_HANDLE_VALUE) {
      fprintf(stderr, "ungeoeffnet zurueck\n");
      return NULL;
   } else { 
      dcb.DCBlength = sizeof(dcb);
      if (GetCommState(hComm, &dcb) == 0) {
         fprintf(stderr, "Probleme mit dem dcb\n");
         return NULL;
      }
      dcb.BaudRate = CBR_9600;
      dcb.ByteSize = 8; /* 8 bits per byte */
      dcb.Parity = 0; /* no parity */
      dcb.StopBits = 0; /* which means: 1 stopbit */
      if (SetCommState(hComm, &dcb) == 0) {
          fprintf(stderr, "Probleme mit den Parametern im dcb\n");
          return NULL;
      
      }
   }
   return hComm;
}

#else

// ====================================
// Linux Variante
// ====================================

SERIALPORT open_port(const char * device) {

int fd; // File-Descriptor

   struct termios SerialPortSettings;

   fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY);
   
   if (fd >= 0) {
        /* SerialPortSettings holen */
        fcntl(fd, F_SETFL, 0);

        if (tcgetattr(fd, &SerialPortSettings) != 0) return(-1);

        cfsetispeed(&SerialPortSettings, B9600); /* setze 9600 bps */
        cfsetospeed(&SerialPortSettings, B9600); /* setze 9600 bps */

        if (statflag_verbose_mode)
           fprintf(stderr, "Speed stimmt !\n");

        /* setze Optionen */
        SerialPortSettings.c_cflag &= ~PARENB;         /* kein Paritybit */
        SerialPortSettings.c_cflag &= ~CSTOPB;         /* 1 Stoppbit */
        SerialPortSettings.c_cflag &= ~CSIZE;          /* 8 Datenbits */
        SerialPortSettings.c_cflag |= CS8;
        SerialPortSettings.c_cflag |= (CLOCAL | CREAD);  /* CD-Signal ignorieren */

        /* Kein Echo, keine Steuerzeichen, keine Interrupts */
        SerialPortSettings.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
        SerialPortSettings.c_oflag &= ~OPOST;          /* setze "raw" Input */
        SerialPortSettings.c_cc[VMIN]  = 0;            /* warten auf min. 0 Zeichen */
        SerialPortSettings.c_cc[VTIME] = 10;           /* Timeout 1 Sekunde */

        tcflush(fd,TCIOFLUSH);

        if (tcsetattr(fd, TCSAFLUSH, &SerialPortSettings) != 0) {
           fprintf(stderr, "Probleme mit den Attributen \n");
           return(-1);
        }
     } else {
       fprintf(stderr, "Probleme beim Oeffnen von  %d\n", fd);
     }
  return(fd);
}

#endif

/* =================================================================
// Windows Entsprechungen des write calls
==================================================================== */
int serial_write(SERIALPORT fd, char * Buffer, int Count) {

#ifdef _WIN32
  int iRet;
  int bytesWritten;

  if (statflag_verbose_mode)
     fprintf(stderr, "Call WriteFile\n");

  iRet = WriteFile (fd, Buffer, Count, &bytesWritten , NULL);

  if (statflag_verbose_mode)
     fprintf(stderr, "Written, %d %d\n", iRet, bytesWritten);

  return bytesWritten;

#else
  return (write(fd, Buffer, Count));
#endif

}

/* =================================================================
// Windows Entsprechungen des read calls
==================================================================== */
int serial_read(SERIALPORT fd, char *buf, int count) {
#ifdef _WIN32
  int iRet;
  int bytesRead;

  // abRet = ::ReadFile(m_hCommPort,szTmp ,sizeof(szTmp ),&dwBytesRead,&ovRead) ;

  if (statflag_verbose_mode)
     fprintf(stderr, "Call ReadFile\n");

  iRet = ReadFile(fd, buf , count, &bytesRead, NULL) ;

  if (statflag_verbose_mode)
     fprintf(stderr, "Read, %d %d %s\n", iRet, bytesRead, buf);

  return bytesRead;
#else
  return read(fd, buf, count);
#endif

}


/* =================================================================
// Sendet Count Bytes aus dem Buffer  in die Schnittstelle
// Return: Anzahl gesendeter Zeichen, 0 bei EOF
//         -1 = ein fehler
==================================================================== */
int sendbytes(SERIALPORT fd, char * Buffer, int Count) {
  int sent;  /* return-Wert */

  /*  Daten senden */
  sent = serial_write(fd, Buffer, Count);
  if (sent < 0) {
    fprintf(stderr, "senden des puffers fehlgeschlagen!\n");
    return -1;
  }

  if (sent < Count) { 
    fprintf(stderr, "Datenstrom beim Senden nach %d Zeichen abgeschnitten\n", sent);
  }

  return sent;
}


/* =================================================================
// len Zeichen aus der Schnittstelle lesen und im buffer ablegen
// Return: Anzahl gelesener Zeichen, 0 bei EOF
//         -1 = ein fehler
==================================================================== */
int get_line(SERIALPORT fd, char *buffer, unsigned int len) {

  int numbytes = 0;
  int ret;
  char buf;

  buf = '\0';

#ifdef _WIN32
  ret = serial_read(fd, buffer, len);
  numbytes = ret;
#else

  while (numbytes <= len) {
    ret = serial_read(fd, &buf, 1);   /* 1 byte lesen*/
    if (statflag_verbose_mode)
        fprintf(stderr, ".");  /* Ein Fortschritt muss zu sehen sein */
    if (ret == 0) break;       /* fertig ! */
    if (ret < 0) return -1;    /* error oder disconnect */
    buffer[numbytes] = buf;    /* byte abspeichern */
    numbytes++;
  }
  if (statflag_verbose_mode)
     fprintf(stderr, "\n");
#endif
  if (statflag_verbose_mode)
     fprintf(stderr, "Gelesen %d, >%s<\n", ret, buffer);

 return numbytes;

}

/* **************************************************************************** */
/* **************************************************************************** */
/* **************************************************************************** */


/* =================================================================
// Vorbereiten eines Datenblocks zum Senden
// Return: 0 = alles OK
//         1 = ein fehler
==================================================================== */
int prepare_data_block(int block, int verwend, int last, char * cp, char * write_buffer, int start) {
   unsigned i;

   unsigned short summe;

   summe = 0;

   // Byte 0: Blocknummer, zaehlt hoch
   // Byte 1: Verwendung 
   //          01 - Info-Block, wird nicht gespeichert 
   //          02 - Programmblock 
   // Byte 2-9 Datenbytes
   // Byte 10 Niederes Byte der Summe über 0-9
   // Byte 11 Folgekennzeichen 
   //          0x0F - Es folgt ein weiterer Datenblock
   //          0xFF - Dateiende

   write_buffer[0] = (char) block; // Blocknummer

   if (block == 0) {
      write_buffer[1] = (char) verwend;
      /* Der Header hat erst mal nur Dummydaten */
      // Byte 2 Startadresse des Programme im Speicher
      write_buffer[2] = (char) start;
      // Byte 3-9 noch unbelegt
      for(i=3;i<10;i++) {
         write_buffer[i]=0x11;
      }
   } else {
      write_buffer[1] = 2;
      for(i=2;i<10;i++) {
         write_buffer[i]=*cp;
         cp++;
      }
   }

   /* Pruefsumme */
   for(i=0;i<10;i++) {
      summe += write_buffer[i];
   }

   write_buffer[10]=(char) summe;

   if (statflag_verbose_mode)
      fprintf(stderr, "Pruefsumme %1x %1x\n", summe, write_buffer[10]);

   if (last == 1)
      write_buffer[11]=(char) 0xFF;
   else
      write_buffer[11]=(char) 0x0F;

   /* Debugausgabe der Bytes des Blocks */
   if (statflag_verbose_mode) {
      fprintf(stderr, "[");
      for(i=0;i<12;i++) 
         fprintf(stderr, " %x ",write_buffer[i]);
      fprintf(stderr, "]\n");
   }
   return 0;
}


/* =================================================================
// Einen Datenblock senden
// Return: Gesemdete Blocknummer = alles OK
//         -1 = ein fehler
==================================================================== */
int send_datablock (SERIALPORT com_fd, char * datablock) {

   int i = 0;
   char Quittung[3]; 

   // Quittung vorsichtigerweise leeren
   while (i < 3)
      Quittung[i++] = '\0';

   i = sendbytes(com_fd, (char *) datablock, 12);
   if (statflag_verbose_mode)
      fprintf(stderr, "send_datablock:  %d Zeichen gesendet\n", i);

   i = get_line(com_fd, Quittung, 2);

   if (statflag_verbose_mode)
      fprintf(stderr, "send_datablock: %d Zeichen zurueckgelesen\n", i);

   // if (Quittung[0] == 0x58 && Quittung[1] == datablock[0]) 
   if (statflag_verbose_mode)
      fprintf(stderr, "Quittung = %x, Blocknummer >%d< - >%d<\n", Quittung[0],  Quittung[1], datablock[0]);

   if (Quittung[0] == 0x58) {
      return datablock[0];
   }
   return -1;
}



/* =================================================================
// Upload einer Datei incl. Retry bei Blockfehlern
// Return: 0 = alles OK
//         1 = ein fehler
// Parameter: Filedescriptor der Schnittstelle, Input oder AUsgabedatei
==================================================================== */
int upload_file(SERIALPORT com_fd, char * infile, int startadr) {

   char ch;
   int i,j;
   int blocknummer;
   char wrk[8]; // Lesepuffer Der eingabedatei, wir lesen immer 8 Bytes und fuellen ggf. mit 0 auf
   int fini = 0; // Zeichen fuer Abschlussblock

   int bytecount = 0;

   char datablock[16]; /* Arbeitsbereich, dieser Block wird dann gesendet */

   char inputdata[1024]; /* Um Timingprobleme zu vermeiden, lesen wir die ganze Batei in den Speicher */

   char * inptr;
   FILE * file_in;

   if (statflag_file_inout) {
       file_in=fopen((const char *) infile, "r");
       if(file_in==NULL) {
         fprintf(stderr, "ERROR: Fehler beim Oeffnen der Datei %s\n", infile);
         return 1;
       }
    } else {
       file_in=stdin;
    }
   
   /* Leseschleife */
   /* Um Timingprobleme zu vermeiden, lesen wir die ganze Batei in den Speicher */
   i = 0;
   while ((ch = fgetc(file_in)) != EOF && i<1024) {
         inputdata[i++] = (unsigned short) ch;
   }

   blocknummer = 0;
   bytecount = i; // Groesse der Eingabedatei

   if (statflag_verbose_mode)
           fprintf(stderr, "Datei (%d Bytes) gelesen\n", bytecount);

   j = 0; // da zaehlen wir die geschriebenen Bytes

   inptr = inputdata;

   while (fini == 0) {

      for (i = 0; i<8; i++) {
         wrk[i] = (unsigned short) *inptr;
         inptr++;
         j++;
      }

      if (j >= bytecount) fini = 1; // Das wird der letzte Block

      while (i<8) {
         wrk[i++] = 0;
         fini = 1;
      }

      if (blocknummer == 0) {
         prepare_data_block(0, 1, 0, wrk, datablock, startadr);

         i = send_datablock (com_fd, datablock);
         if (statflag_verbose_mode)
            fprintf(stderr, "Block %d uebertragen \n", i);
         if (i == -1) {
            fprintf(stderr, "Upload Headerblock zu boris fehlgeschlagen\n");
            return 1;
         }
         blocknummer++;
      }

      if (prepare_data_block(blocknummer, 2, fini, wrk, datablock, 0) != 0) {
         fprintf(stderr, "Vorbereitung Datenblock fehlgeschlagen\n");
         return 1;
      } else {
         if (statflag_verbose_mode)
            fprintf(stderr, "Datenblock %d vorbereitung  war erfolgreich\n", blocknummer);
      }

      i = send_datablock (com_fd, datablock);
      if (statflag_verbose_mode)
         fprintf(stderr, "Block %d uebertragen (%d)\n", blocknummer, i);
      if (i == -1) {
         fprintf(stderr, "Upload Datenblock zu boris fehlgeschlagen - retry\n");
         // tcflush(com_fd,TCIOFLUSH);
         i = send_datablock (com_fd, datablock);
         if (statflag_verbose_mode)
            fprintf(stderr, "Block %d uebertragen (%d)\n", blocknummer, i);
         if (i == -1) {
            fprintf(stderr, "Upload Datenblock zu boris fehlgeschlagen - retry\n");
            // Abbruch-Kennzeichen schicken
            for (i=0; i<12; i++) {
               datablock[i] = 0xFF;
            }
            send_datablock (com_fd, datablock);
            return 1;
         }
      }
      blocknummer++;
   }

   if (statflag_file_inout) {
         fclose(file_in);
   }

   return 0;
}


/* =================================================================
==================================================================== */
int run_program(SERIALPORT com_fd, int start) {

   int i;
   char wrk[8]; // Lesepuffer Der eingabedatei, wir lesen immer 8 Bytes und fuellen ggf. mit 0 auf

   char datablock[16]; /* Arbeitsbereich, dieser Block wird dann gesendet */

   prepare_data_block(0, 3, 1, wrk, datablock, start);

   i = send_datablock (com_fd, datablock);
   if (statflag_verbose_mode)
            fprintf(stderr, "Block %d uebertragen \n", i);
   if (i == -1) {
            fprintf(stderr, "Upload Headerblock zu boris fehlgeschlagen\n");
            return 1;
   }

   return 0;
}

// Datenblock aus der Schnittstelle lesen
//   
//    Byte 0: Blocknummer, zaehlt hoch
//    Byte 1: Verwendung 
//             01 - Info-Block, wird nicht gespeichert 
//             02 - Programmblock 
//    Byte 2-9 Datenbytes
//    Byte 10 Niederes Byte der Summe über 0-9
//    Byte 11 Folgekennzeichen 
//             0x0F - Es folgt ein weiterer Datenblock
//             0xFF - Dateiende
//   
// Return: 0x0f - noch ein Block kommt
//         0xff - Dateiende, alles OK
//         Alles andere: Fehler!
//   
char get_datablock (SERIALPORT com_fd, int blocknummer, FILE * file_out) {

   int i;
   char Quitt[8];
   unsigned short xx;
   char summe;
   char Lesepuffer[16]; /* Eigentlich brauchen wir nur 12 Zeichen */

   int cnt = 0; // Simples Retry?

   if (statflag_verbose_mode)
      fprintf(stderr, "Vorbereiten des Lesepuffers für Block Nr.  %d \n", blocknummer);

   for(i=0;i<16;i++) {
       Lesepuffer[i] = (char) 0;
   }

   if (statflag_verbose_mode)
      fprintf(stderr, "Lesen wir den Block nr. %d \n", blocknummer);

   do {
      i = get_line(com_fd, Lesepuffer, 12);
      // tcflush(com_fd,TCIOFLUSH);
      cnt++;
   } while (i < 1 && cnt < 5);

   if (statflag_verbose_mode)
      fprintf(stderr, "get_line: %d\n", i);

   // fprintf(stderr, ">%s<\n", Lesepuffer);

   if (statflag_verbose_mode) {
        fprintf(stderr, "{");
        for(i=0;i<12;i++) {
            xx = (unsigned short) Lesepuffer[i];
            xx = xx%256;
            fprintf(stderr, " %x", xx);
        }
            fprintf(stderr, "}\n");
   }

   if (Lesepuffer[0] == blocknummer) {
     // Es koennte genau der Block sein, den wir wollen
     if (statflag_verbose_mode) 
         fprintf(stderr, " Blocknummer %d passt\n", blocknummer);

     summe = 0;
     /* Pruefsumme */
     for(i=0;i<10;i++) {
        summe += (unsigned short) Lesepuffer[i];
        // fprintf(stderr, "summe =  %d\n", summe);
     }

     if (summe == Lesepuffer[10]) {
         // Der Block ist valid!
        if (statflag_verbose_mode) 
            fprintf(stderr, " Pruefsumme %d passt\n", summe);

        for(i=2;i<10;i++) {
            xx = (unsigned short) Lesepuffer[i];
            xx = xx%256;
            // fprintf(stderr, " %d %x\n", i, xx);
            if (Lesepuffer[1] == (char) 2) 
                fprintf(file_out, "%c", (char) xx);
        }

        // Quittung senden
        Quitt[0] = 0x58;
        Quitt[1] = blocknummer;
        // Quitt[1] = '\n';
        i = sendbytes(com_fd, (char *) Quitt, 2);
        // i = sendbytes(com_fd, (char *) &Quitt[0], 1);
        // i = sendbytes(com_fd, (char *) &Quitt[1], 1);

        if (statflag_verbose_mode)
           fprintf(stderr, "Quittung %d Zeichen gesendet\n", i);
        return Lesepuffer[11];

     } else {
        fprintf(stderr, " Pruefsumme %d passt nicht zu %d\n", summe, Lesepuffer[10]);
     }
   } else {
      fprintf(stderr, " Blocknummer %d passt nicht zu %d !\n", blocknummer, Lesepuffer[0]);
   }
   return 7;
}


/* =================================================================
// Download einer Datei incl. Retry bei Blockfehlern
// Return: 0 = alles OK
//         1 = ein fehler
// Parameter: Filedescriptor der Schnittstelle, Input oder AUsgabedatei
==================================================================== */
int download_file(SERIALPORT com_fd, char * infile) {
  char i;
  int bl;
  
   FILE * file_out;

   if (statflag_file_inout) {
       file_out=fopen((const char *) infile, "w+");
       if(file_out==NULL) {
         fprintf(stderr, "ERROR: Fehler beim Oeffnen der Datei %s\n", infile);
         return 1;
       }
    } else {
       file_out=stdin;
    }
   
  i = get_datablock(com_fd, 0, file_out);

  if (statflag_verbose_mode)
      fprintf(stderr, "Headerblock will mehr %x\n", i);

  for (bl = 1; bl < 50 && i == 0x0F; bl++) {
     i = get_datablock(com_fd, bl, file_out);
  }

  if (statflag_file_inout) {
    fclose(file_out);
  }

  if (i == (char) 0xff) {
     return 0;
  } else {
     return (int) i;
  }
}

void usage(char * Program) {
   fprintf(stderr, "%s - Ein Kommandozeilen Terminal fuer boris4 - Programme\n\n",Program);
   fprintf(stderr, "Bitteschoen: %s [-u | -d | -r] [-v] [-f Eingabedatei] [-s Startadresse] device\n",Program);
   fprintf(stderr, "     -u          Upload zu boris\n");
   fprintf(stderr, "     -d          Download von boris\n");
   fprintf(stderr, "     -r          Programmstart auf boris\n");
   fprintf(stderr, "     -s adresse  Adresse fuer den Programmstart (default: 0)\n");
   fprintf(stderr, "     -f Datei    Eingabe aus einer Datei lesen / in eine Datei schreiben (default: stdin)\n");
   fprintf(stderr, "     -v          Verbose mode\n");
}


int main(int argc, char * argv[]) {

   char infile[256]; /* Dateiname der Ein/Ausgabedatei */
   SERIALPORT com_fd;       /* File-Descriptor der seriellen Schnittstelle */
   int index;
   int modus = 0;    /* Arbeitsmodus up/down */

   unsigned i;
   char c, Zeichen;
   char Lesepuffer[64];
   char device[64];
   char startadr_str[64];
   int startadr;

   startadr = 0;

   while ((c = getopt (argc, argv, (const char *) "udrf:s:vh")) != -1) {
        switch (c)
          {
          case 'u':
            modus = 1;
            break;
          case 'd':
            modus = 2;
            break;
          case 'r':
            modus = 3;
            break;
          case 'v':
            statflag_verbose_mode = 1;
            break;
          case 'f':
            statflag_file_inout = 1;
            if (strlen(optarg) < 255) {
                strcpy(infile, optarg);
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

      if (statflag_verbose_mode) {
         fprintf (stderr, "statflag_file_inout = %d\n", statflag_file_inout);

         for (index = optind; index < argc; index++) {
           fprintf (stderr, "Non-option argument %s\n", argv[index]);
         }
      }

      index = optind;


      if (index >= argc) {
          fprintf (stderr, "Parameterfehler index %d, argc %d\n", index, argc);
          usage(argv[0]);
          return 1;
      } else {
          strcpy(device, argv[index]);
      }

      if (statflag_verbose_mode)
         fprintf(stderr, "Files: Device: >%s< Infile: >%s<\n", device, infile);

      if(strlen(device) == 0) {
         usage(argv[0]);
      }


     if(strlen(device) == 0) {
         usage(argv[0]);
     }

     if(strlen(device) == 0) {
         usage(argv[0]);
     } else {
         if (statflag_verbose_mode)
            fprintf(stderr, "Programmstart mit %s\n", device);
         com_fd = open_port(device);

#ifdef _WIN32
         if (com_fd == NULL) 
#else
         if (com_fd == -1) 
#endif         
         {
             fprintf(stderr, "Probleme mit dem device %s %d\n", device, com_fd);
             return 1;
         } else {
             if (statflag_verbose_mode)
                fprintf(stderr, "Ready to rumble!  %s %d\n", device, com_fd);
         }
         Zeichen = 0xaa;
         i = sendbytes(com_fd, &Zeichen, 1);
         if (statflag_verbose_mode)
            fprintf(stderr, "%d Initialisierungscode gesendet\n", i);
          
         i = get_line(com_fd, Lesepuffer, 8);
         // tcflush(com_fd,TCIOFLUSH);

         if (statflag_verbose_mode) {
            fprintf(stderr, "%d Zeichen Antwort empfangen\n", i);
            Lesepuffer[i] = '\0';
            fprintf(stderr, "%s\n", Lesepuffer);
         }
          
         if (modus == 1) { // UPLOAD
             Zeichen = 0x54;
             i = sendbytes(com_fd, &Zeichen, 1);
             if (statflag_verbose_mode)
                fprintf(stderr, "%c (%d Zeichen) Kommando gesendet\n", Zeichen, i);
          
             if (upload_file(com_fd, infile, startadr) != 0) {
                 fprintf(stderr, "Upload zu boris fehlgeschlagen\n");
                 return 1;
             } else {
                 if (statflag_verbose_mode)
                    fprintf(stderr, "Upload zu boris war erfolgreich\n");
             }

         }

         if (modus == 2) { // DOWNLOAD
             Zeichen = 0x55;
             i = sendbytes(com_fd, &Zeichen, 1);
             if (statflag_verbose_mode)
                fprintf(stderr, "%c (%d Zeichen) Kommando gesendet\n", Zeichen, i);
          
             if ((i = download_file(com_fd, infile)) != 0) {
                 fprintf(stderr, "Download von boris fehlgeschlagen %d\n", (unsigned) i);
                 return 1;
             } else {
                 if (statflag_verbose_mode)
                    fprintf(stderr, "Download von boris war erfolgreich\n");
             }

         }

         if (modus == 3) { // RUN
             Zeichen = 0x56;
             i = sendbytes(com_fd, &Zeichen, 1);
             if (statflag_verbose_mode)
                fprintf(stderr, "%c (%d Zeichen) Kommando gesendet\n", Zeichen, i);
          
             if (run_program(com_fd, startadr) != 0) {
                 fprintf(stderr, "Programmstart auf boris fehlgeschlagen\n");
                 return 1;
             } else {
                 if (statflag_verbose_mode)
                    fprintf(stderr, "Programmstart ausgeloest\n");
             }

         }

         /* Close the serial port */
#ifdef _WIN32
         CloseHandle(com_fd);
#else
         close(com_fd); 
#endif
         
   }
   return 0;
}





/*

Now, when you have a COM port open, you may want to send some data to the connected device. For example, let's say you want to send "Hello" to the device (for example, another PC). When you want to send the data across the serial port, you need to write to the serial port just as you would write to a file. You would use following API:

iRet = WriteFile (m_hCommPort,data,dwSize,&dwBytesWritten ,&ov);
where data contains "Hello".

Let's say that, in response to your "Hello", the device sends you "Hi". So, you need to read the data. Again, you would use the following API:

abRet = ::ReadFile(m_hCommPort,szTmp ,sizeof(szTmp ),&dwBytesRead,&ovRead) ;
For now, do not try to understand everything. We will get to all this later. All this sounds very simple. Right?
Now, let's start digging into issues.

*/

