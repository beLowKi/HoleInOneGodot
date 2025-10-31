Heres how Charts and other song stuff works--all in one place


The main thing of charts is their list of Sections, which have a list of Measures, which are lists of Notes.


Sections
	. Contains meta data like time signature, bpm, key signature, etc.
	. Has list of measures

Measures
	. Has measure number
	. Mostly just a list of notes

Notes
	. Has a note_key which relates to its track number that determines what it actually "does" during
		gameplay
	. Within the actual midi file that Charts are loaded from, C, C#, D, D#, F, F#, G, and G# are single-input notes
		-> A note's sharp is used for their build_up time
	. Can be held or tapped
