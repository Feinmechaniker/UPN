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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


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

 
