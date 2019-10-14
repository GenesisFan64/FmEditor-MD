# FmEditor-MD
FM patch editor for Genesis/MegaDrive

This was designed to be used with the PulseMini sound driver, to save the instruments
use savestates and to use them, in your assembly code set start position at $2478 and the length of $20 bytes

Example:
    binclude "game/sound/instr/fm/bass_beach_2.gsx",2478h,20h
(instrument located at Z80)
