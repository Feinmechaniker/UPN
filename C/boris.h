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

#ifndef _BORIS_H
#define _BORIS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef _WIN32

#include <getopt.h>
#include <termios.h> /* POSIX Terminal Control Definitions */
#include <unistd.h>  /* UNIX Standard Definitions */
#include <sys/ioctl.h>

#else
int getopt(int nargc, char * const nargv[], const char *ostr);
#endif

#include <ctype.h>
#include <fcntl.h>   /* File Control Definitions           */

#include <errno.h>   /* ERROR Number Definitions */

#ifdef _WIN32
#include <io.h>
#endif


/* Hier ein Feld mit den symbolischen Kommandocodes */

char *kdo_4_codes[128] = {"NOP", 
 "+", 
 "-", 
 "*", 
 "/", 
 ".", 
 "ENTER", 
 "STO", 
 "RCL", 
 "SQRT", 
 "GOTO", 
 "GOSUB", 
 "RETURN", 
 "LN", 
 "HALT", 
 "CX", 
 "X^Y", 
 "X<->Y", 
 "STO+", 
 "STO-", 
 "STO*", 
 "STO/", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "0", 
 "1", 
 "2", 
 "3", 
 "4", 
 "5", 
 "6", 
 "7", 
 "8", 
 "9", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "DIMM", 
 "CHS", 
 "RND", 
 "1/X", 
 "FIX", 
 "RDN", 
 "", 
 "", 
 "SQR", 
 "X>0", 
 "X=0", 
 "X<0", 
 "E^X", 
 "PRG", 
 "NOP", 
 "PI", 
 "LSTX", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "", 
 "GRD", 
 "INT", 
 "FRAC", 
 "ABS", 
 "ASIN", 
 "ACOS", 
 "ATAN", 
 "SIN", 
 "COS", 
 "TAN", 
 "", 
 "", 
 "", 
 "", 
 "END", 
 ""};

char *kdo_5_codes[256] = {"NOP",
 "+",
 "-",
 "*",
 "/",
 ".",
 "ENTER",
 "STO",
 "RCL",
 "SQRT",
 "GOTO",
 "GOSUB",
 "RETURN",
 "LN",
 "HALT",
 "CX",
 "X^Y",
 "X<->Y",
 "STO+",
 "STO-",
 "STO*",
 "STO/",
 "",
 "",
 "",
 "",
 "",
 "",
 "SIN",
 "COS",
 "TAN",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "0",
 "1",
 "2",
 "3",
 "4",
 "5",
 "6",
 "7",
 "8",
 "9",
 "A",
 "B",
 "C",
 "D",
 "E",
 "F",
 "",
 "PAUSE",
 "/-/",
 "RND",
 "1/X",
 "FIX",
 "RDN",
 "",
 "",
 "SQR",
 "IF X>0",
 "IF X=0",
 "IF X<0",
 "E^X",
 "RUN",
 "NOP",
 "PI",
 "LSTX",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "ASIN",
 "ACOS",
 "ATAN",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "GRD",
 "INT",
 "FRAC",
 "ABS",
 "IF X>Y",
 "IF X=Y",
 "IF X<Y",
 "LOOP7",
 "LOOP8",
 "LOOP9",
 "",
 "",
 "",
 "",
 "END", 
 "",
// HIer die erweiterungen (Indexfunktion)
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "STO IX",
 "RCL IX",
 "",
 "GOTO IX",
 "GOSUB IX",
 "",
 "",
 "",
 "",
 "",
 "",
 "STO+ IX",
 "STO- IX",
 "STO* IX",
 "STO/ IX",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "IF X>0 IX",
 "IF X=0 IX",
 "IF X<0 IX",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "IF X>Y IX",
 "IF X=Y IX",
 "IF X<Y IX",
 "LOOP7 IX",
 "LOOP8 IX",
 "LOOP9 IX",
 "",
 "",
 "",
 "",
 "",
 "NOP"};

char *kdo_6_codes[256] = {"NOP",
 "+",
 "-",
 "*",
 "/",
 ".",
 "ENTER",
 "STO",
 "RCL",
 "SQRT",
 "GOTO",
 "GOSUB",
 "/-/",
 "1/x",
 "HALT",
 "CX",
 "y^x",
 "x<->y",
 "STO+",
 "STO-",
 "STO*",
 "STO/",
 "",
 "END",
 "",
 "",
 "",
 "",
 "SIN",
 "COS",
 "TAN",
 "EEX",
 "10^X",
 "",
 "e^X",
 "INT",
 "RDN",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "0",
 "1",
 "2",
 "3",
 "4",
 "5",
 "6",
 "7",
 "8",
 "9",
 "A",
 "B",
 "C",
 "D",
 "E",
 "F",
 "",
 "RND",
 "",
 "grd",
 "Fix",
 "",
 "LSTx",
 "SFILE",
 "LFILE",
 "SQR",
 "PAUSE",
 "RETURN",
 "PI",
 "",
 "RUN",
 "CReg",
 "x^y",
 "CPrg",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "ASIN",
 "ACOS",
 "ATAN",
 "ABS",
 "LOG",
 "",
 "LN",
 "FRAC",
 "ROLLUP",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "IF x=y",
 "IF x>y",
 "IF x<y",
 "IF x=0",
 "IF x>0",
 "IF x<0",
 "Loop 7",
 "Loop 8",
 "Loop 9",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "+",
 "-",
 "*",
 "/",
 ".",
 "ENTER",
 "STO    Ix",
 "RCL    Ix",
 "SQRT",
 "GOTO   Ix",
 "GOSUB  Ix",
 "/-/",
 "1/x",
 "HALT",
 "CX",
 "y^x",
 "x<->y",
 "STO+   Ix",
 "STO-   Ix",
 "STO*   Ix",
 "STO/   Ix",
 "",
 "END",
 "",
 "",
 "",
 "",
 "SIN",
 "COS",
 "TAN",
 "EEX",
 "10^X",
 "",
 "e^X",
 "INT",
 "RDN",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "0",
 "1",
 "2",
 "3",
 "4",
 "5",
 "6",
 "7",
 "8",
 "9",
 "A",
 "B",
 "C",
 "D",
 "E",
 "F",
 "",
 "RND",
 "",
 "grd    Ix",
 "Fix    Ix",
 "",
 "LSTx",
 "SFILE  Ix",
 "LFILE  Ix",
 "SQR",
 "PAUSE",
 "RETURN",
 "PI",
 "",
 "RUN",
 "C Reg",
 "x^y",
 "C Prg",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "ASIN",
 "ACOS",
 "ATAN",
 "ABS",
 "LOG",
 "",
 "LN",
 "FRAC",
 "ROLLUP",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "",
 "IF x=y Ix",
 "IF x>y Ix",
 "IF x<y Ix",
 "IF x=0 Ix",
 "IF x>0 Ix",
 "IF x<0 Ix",
 "Loop 7 Ix",
 "Loop 8 Ix",
 "Loop 9 Ix",
 "",
 "",
 "",
 "",
 "",
 "NOP"};



#ifdef _WIN32

/* ****************************************************************************
*  getopt is not contained in VC. So lets use the implementation below
* **************************************************************************** */


/*
* Copyright (c) 1987, 1993, 1994
*      The Regents of the University of California.  All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
* 1. Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
* 2. Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
* 3. All advertising materials mentioning features or use of this software
*    must display the following acknowledgement:
*      This product includes software developed by the University of
*      California, Berkeley and its contributors.
* 4. Neither the name of the University nor the names of its contributors
*    may be used to endorse or promote products derived from this software
*    without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
* OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
* SUCH DAMAGE.
*/


int     opterr;              /* if error message should be printed */
int     optind;              /* index into parent argv vector */
int     optopt;                 /* character checked for validity */
int     optreset;               /* reset getopt */
char    *optarg;                /* argument associated with option */

#define BADCH   (int)'?'
#define BADARG  (int)':'
#define EMSG    ""

opterr = 1;
optind = 1;



/*
* getopt --
*      Parse argc/argv argument vector.
*/
int getopt(int nargc, char * const nargv[], const char *ostr) {
  static char *place = EMSG;              /* option letter processing */
  const char *oli;                        /* option letter list index */

  if (optreset || !*place) {              /* update scanning pointer */
    optreset = 0;
    if (optind >= nargc || *(place = nargv[optind]) != '-') {
      place = EMSG;
      return (-1);
    }
    if (place[1] && *++place == '-') {      /* found "--" */
      ++optind;
      place = EMSG;
      return (-1);
    }
  }                                       /* option letter okay? */
  if ((optopt = (int)*place++) == (int)':' ||
    !(oli = strchr(ostr, optopt))) {
      /*
      * if the user didn't specify '-' as an option,
      * assume it means -1.
      */
      if (optopt == (int)'-')
        return (-1);
      if (!*place)
        ++optind;
      if (opterr && *ostr != ':')
        (void)printf("illegal option -- %c\n", optopt);
      return (BADCH);
  }
  if (*++oli != ':') {                    /* don't need argument */
    optarg = NULL;
    if (!*place)
      ++optind;
  }
  else {                                  /* need an argument */
    if (*place)                     /* no white space */
      optarg = place;
    else if (nargc <= ++optind) {   /* no arg */
      place = EMSG;
      if (*ostr == ':')
        return (BADARG);
      if (opterr)
        (void)printf("option requires an argument -- %c\n", optopt);
      return (BADCH);
    }
    else                            /* white space */
      optarg = nargv[optind];
    place = EMSG;
    ++optind;
  }
  return (optopt);                        /* dump back option letter */
}

#endif
 
#endif


