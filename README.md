# FmEditor-MD
FM patch editor for Genesis/MegaDrive

This was designed to be used with the PulseMini sound driver

To save the patch use Fusion's savestates (.gsx)
And to use them on PulseMini, In your assembly code use binclude/incbin, set the START position at $2478 and the LENGTH to $20 bytes

Example:
    binclude "game/sound/instr/fm/bass_beach_2.gsx",2478h,20h
(instrument located at Z80)
