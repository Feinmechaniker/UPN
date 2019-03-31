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
#else
int getopt(int nargc, char * const nargv[], const char *ostr);
#endif

/* Funktionsprototypen */

char * get_cmd_str(char code);
unsigned short get_cmd_cde(char * code);

int is_comment(char *line);
int is_empty_line(char *line);
int isWspace (char p_zeichen);

int main(int argc, char * argv[]);
int needs_adress(char code);
int needs_mem_adress(char code);
int needs_param(char code);
int needs_prog_adress(char code);

static char * prepare_output_line(char *marke, char *kdo, int adresse, int ch);
void prep_marke(char * marke, int flag, int a);

void usage(char * Program);


/* Hier ein Feld mit den symbolischen Kommandocodes */

char *kdo_codes[128] = {"NOP", 
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


