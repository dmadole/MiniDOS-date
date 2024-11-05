
;  Copyright 2022, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.

#include include/bios.inc
#include include/kernel.inc


            ; Executable program header

            org   1ffah
            dw    start
            dw    end-start
            dw    start

start:      br    skipspc


            ; Build information

            db    5+80h                 ; month
            db    11                    ; day
            dw    2024                  ; year
            dw    2                     ; build

            db    'See github.com/dmadole/MiniDOS-date for more info',0


skipspc:    lda   ra                    ; skip until non-space or end of line
            lbz   notargs
            smi   ' '
            lbz   skipspc

            dec   ra                    ; backup to non-space character

            ldi   low datebuf           ; get pointer to date buffer
            plo   rb
            ldi   high datebuf
            phi   rb

            ldi   low dateinp           ; get address of format table
            plo   rc
            ldi   high dateinp
            phi   rc

            glo   ra                    ; get pointer to input arguments
            plo   rf
            ghi   ra
            phi   rf

datenxt:    sep   scall                 ; get next number, error otherwise
            dw    f_atoi
            lbdf  datefmt

            sex   rc                    ; arithmetic against table entries

            glo   rd                    ; subtract lowest value from input
            inc   rc
            sm
            ghi   rd
            dec   rc
            smb
            lbnf  datebad               ; error if input valuer is lesser

            inc   rc                    ; advance over lowest value
            inc   rc

            glo   rd                    ; subtract input from highest value
            inc   rc
            sd
            ghi   rd
            dec   rc
            sdb
            lbnf  datebad               ; error if highest value is lesser

            inc   rc                    ; advance over highest value
            inc   rc

            glo   rd
            str   rb

            ldn   rc
            smi   ' '
            lbnz  skpyear

            glo   rd
            smi   low 1972
            str   rb

skpyear:    inc   rb
            ldn   rc                    ; done if end of expected separators
            lbz   datechk

            lda   rf                    ; get next if separator is correct,
            sm                          ;  skip over separator
            inc   rc
            lbz   datenxt


            ; Error messages for the two things that can go wrong while
            ; parsing dates -- the wrong format or not a valid date.

datefmt:    sep   scall                 ; if the format is wrong
            dw    o_inmsg
            db    'ERROR: Use date format "MM/DD/YY HH:MM:SS"',13,10,0
            sep   sret

datebad:    sep   scall                 ; if an element if out of range
            dw    o_inmsg
            db    'ERROR: Argument is not a valid date',13,10,0
            sep   sret


            ; Table that describes the order and format of date items, each
            ; entry consists of the lowest and highest values accepted, the
            ; byte value to subtract from the lsb to get the internal date
            ; representation, and the separator that should appear after each
            ; item, with a zero marking the end of the list.

dateinp:    dw    1,12                  ; month
            db    '/'
            dw    1,31                  ; day
            db    '/'
            dw    1972,2071             ; year
            db    ' '
            dw    0,23                  ; hour
            db    ':'
            dw    0,59                  ; minute
            db    ':'
            dw    0,59                  ; second
            db    0


            ; Now that the basic validation and conversion is done, check
            ; that the number of days in the month is valid for the date.

datechk:    ldi   low datebuf          ; pointer to date buffer
            plo   rb
            ldi   high datebuf
            phi   rb

            ldn   rb                   ; get month, add bit 3 with bit 1,
            smi   8                    ;  if result odd, month has 31 days
            adci  0
            shr
            lbdf  wrtdate              ; we already checked 31 days

            ldi   30                   ; assume 30 days until determined else
            plo   re

            lda   rb                   ; get month again, advance to day,
            smi   2                    ;  check if month is february
            lbnz  monthday

            dec   re                   ; assume 28 days until determined else
            dec   re

            inc   rb                   ; if year is 2000 then 28 days
            ldn   rb
            dec   rb
            smi   2000-1972
            lbz   monthday

            ani   3                    ; if not divisible by 4 then 28 days
            lbnz  monthday

            inc   re                   ; all else is leap year so 29 days

monthday:   glo   re
            sex   rb
            sm
            lbnf  datebad


            ; We have a good date, so set the RTC if one is present, else
            ; update the sytem date variable with it.

wrtdate:    sep   scall                ; get devices known by system
            dw    o_getdev

            glo   rf                   ; test if rtc is present
            ani   10h
            lbz   cpydate

            ldi   low datebuf
            plo   rf
            ldi   high datebuf
            phi   rf

            sep   scall
            dw    o_settod

            sep   sret
       
cpydate:    ldi   low datebuf
            plo   rb
            ldi   high datebuf
            phi   rb

            lda   low K_MONTH
            plo   rf
            lda   high K_MONTH
            phi   rf

            ldi   6
            plo   re

cpyloop:    lda   rb
            str   rf
            inc   rf
            dec   re
            glo   re
            lbnz  cpyloop

            sep   sret


            ; If no argument was supplied on the command line, then get the
            ; time from the RTC and print it, if present.

notargs:    sep   scall                 ; read rtc if one is present
            dw    o_getdev

            glo   rf                    ; test if rtc is present
            ani   10h
            lbz   dateprt

            ldi   low datebuf           ; pointer to date buffer
            plo   rf
            ldi   high datebuf
            phi   rf

            sep   scall                 ; read the RTC
            dw    o_gettod

            ldi   low datebuf           ; start from end of data buffer
            plo   rb
            ldi   high datebuf
            phi   rb

            lbr   dateprt


            ; If no RTC, then print the system date variable.

sysdate:    ldi   low K_MONTH           ; date variable but start from end
            plo   rb
            ldi   high K_MONTH
            phi   rb


            ; Regardless of anything else we have done, finally print the
            ; date from the system variable.

dateprt:    ldi   low bothout           ; date output format table
            plo   rc
            ldi   high bothout
            phi   rc

            ldi   low buffer            ; text output buffer but from end
            plo   rf
            ldi   high buffer
            phi   rf

            sep   scall
            dw    datefil

            sep   sret


datefin:    str   rf
            inc   rf                    ; advance table pointer

datefil:    lda   rc                    ; adjust the year if a space
            lbnz  adjyear

            ldi   0                     ; otherwise lsb is zero
            phi   rd

            lda   rb                    ; if msb is 10 or more just print
            plo   rd
            smi   10
            lbdf  tenmore

            ldi   '0'                   ; if less than 10 output a leading 0
            str   rf
            inc   rf
            lbr   tenmore

adjyear:    lda   rb                    ; add 1972 to stored date
            adi   low 1972
            plo   rd
            ldi   0
            adci  high 1972
            phi   rd

tenmore:    sep   scall                 ; number and advance rf
            dw    f_intout

            lda   rc                    ; if separator non-zero get more,
            lbnz  datefin

            ldi   13
            str   rf
            inc   rf

            ldi   10
            str   rf
            inc   rf

            ldi   0
            str   rf

            ldi   low buffer            ; text output buffer but from end
            plo   rf
            ldi   high buffer
            phi   rf

            sep   scall
            dw    o_msg

            sep   sret


bothout:    db    0,'/'                 ; types and delimiters, zero to end
            db    0,'/'
            db    1,' '
timeout:    db    0,':'
            db    0,':'
            db    0, 0
dateout:    db    0,'/'
            db    0,'/'
            db    1, 0




datebuf:   ds    6
buffer:    ds    24

end:       ; That's all folks!

