extends Node
## Signal dump


# Rhythm-related - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >
# Event though I COULD just make anything that want to reference these connect directly to the RhythmEngine,
# that sounds like a hassle, so I'm making the important ones global.


# These are all different signals because different objects care about different changes
# i.e. the stylus cares when the chart changes, but the audio_hub only cares when the song changes or
# the metronome only cares when the bpm or time_signature does. Most of the time, all these things are
# changed at the same time, but not always
## Chart change
@warning_ignore("unused_signal")
signal chart_changed
## Song change so that rhythm configs are synced; emits the file path
@warning_ignore("unused_signal")
signal song_changed
## When ts changes
@warning_ignore("unused_signal")
signal time_signature_changed
## Same but for bpm
@warning_ignore("unused_signal")
signal bpm_changed


# Song-tracking; yes, Stylus controls most of these, but they're going to be referenced globally

## Called on the first measure of a song
@warning_ignore("unused_signal")
signal song_started

@warning_ignore("unused_signal")
signal song_ended

## On-beat; in eighth note time_signatures, it's on every count (1, 2, 3, 4, 5, and 6 in 6/8)
@warning_ignore("unused_signal")
signal beat
## Emits when stylus detects new section
@warning_ignore("unused_signal")
signal section_changed(s:Section)
## Same but for measures
@warning_ignore("unused_signal")
signal measure_changed(m:Measure)
## When RhythmEvent begins
@warning_ignore("unused_signal")
signal event_started(ev:SongEvent)
## When an event receives its input; offset is (activated_time - start_time)
@warning_ignore("unused_signal")
signal event_activated(ev:RhythmInputEvent, score:Utils.SCORES, offset:float)
## When an event's window ends without input
@warning_ignore("unused_signal")
signal event_missed

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >
