=====================================================
 WAFU Vol.19 - Japanese Underworld Music Pack
 "The Road Down"
 12 tracks + seamless loops + 8 underworld cues
 (WAV + OGG)

 FREE. This is a complete volume, not a sample.
=====================================================

Thank you for downloading WAFU Vol.19!

This one is free, and it is not a trial version. It is a full WAFU
volume: six areas, two tracks each, loops engineered by hand, cues cut
by hand, same license as every pack we sell. Nothing is held back and
nothing expires.

It is the Japanese underworld - Yomi, the land of the dead - written
as a place you descend through: the river crossing, the gate, the hall
where the verdict is read, a plain of ash with no landmarks, whatever
rules the place, and the road back that keeps arriving where it began.

It is built for roguelike and roguelite descents, dark fantasy RPGs,
souls-likes and dungeon crawlers. It is scale and myth rather than
jump scares: koto, shakuhachi, hichiriki, sho, taiko and temple bells
over very low drones.


CONTENTS
--------
/WAV/Full/       12 full tracks (WAV 48kHz 16bit stereo)
                 Complete versions with natural endings.

/WAV/Loop/       12 seamless loop versions (WAV 48kHz 16bit stereo)
                 Silence trimmed, the tail crossfaded back into the
                 opening. Set your engine to loop the whole file:
                 when playback jumps from the end back to the start,
                 there is no audible seam.

/WAV/Stingers/   8 underworld cues (WAV 48kHz 16bit stereo)
                 One-shots. Do not loop these.

/OGG/Full/       Same as WAV/Full, in OGG Vorbis (high quality).
/OGG/Loop/       Same as WAV/Loop, in OGG Vorbis (high quality).
/OGG/Stingers/   Same cues in OGG, for the sound channel.
                 OGG is recommended for Godot / Unity / RPG Maker.


TRACK LIST
----------
01 The River I            The_River_01    2:18   (The crossing - first area)
02 The River II           The_River_02    3:09   (The crossing - first area)
03 The Gate I             The_Gate_01     2:27   (Between areas, the entrance)
04 The Gate II            The_Gate_02     2:43   (Between areas, the entrance)
05 Judgement I            Judgement_01    2:49   (The verdict - a boss)
06 Judgement II           Judgement_02    2:42   (The verdict - a boss)
07 The Plain of Ash I     Ash_Plain_01    2:59   (The long empty stretch)
08 The Plain of Ash II    Ash_Plain_02    2:39   (The long empty stretch)
09 The Ruler I            The_Ruler_01    2:33   (Final boss, or the hub)
10 The Ruler II           The_Ruler_02    3:12   (Final boss, or the hub)
11 No Way Out I           No_Way_Out_01   2:18   (Death, retry, run failed)
12 No Way Out II          No_Way_Out_02   2:14   (Death, retry, run failed)

Total running time: 32 minutes 9 seconds.
Every track runs past two minutes.


UNDERWORLD CUES
---------------
Cue_Toll_01 / _02          3.0s  A deep temple bell. Entering an area, a checkpoint.
Cue_Curse_01 / _02         2.0s  A dissonant stab and a metal scrape. A debuff lands.
Cue_Soul_01 / _02          3.5s  A high tone thinning over a bell. A soul collected.
Cue_Doom_01 / _02          4.0s  A taiko strike, strings collapsing. The player dies.

Two variants of each. Normalized to -1 dBFS, so they are loud: if a
soul pickup can happen every few seconds in your game, turn Cue_Soul
down on your mixer rather than letting it cut through every time.


HOW TO USE THEM
---------------
One descent, one playlist per area:

  first area              The River
  moving between areas    The Gate        (+ Cue_Toll on arrival)
  long quiet stretches    The Plain of Ash
  boss                    Judgement
  final boss or hub       The Ruler
  death / run failed      Cue_Doom, then No Way Out

Two takes of every scene: use _01 on the first run and _02 on later
runs, or alternate them floor by floor.

Silence is part of the design. Players start to notice a loop after
three to five repeats. Souls-likes often play no music at all outside
bosses and rest points. Letting a track play a couple of times and
then leaving 20-40 seconds of silence makes the next entrance feel
like a change of place instead of the same loop again. The helper
below does exactly that.

- Godot:      Import the Loop OGG. For the helper below, turn loop OFF
              in the import settings so the "finished" signal fires.
- Unity:      Import the Loop version. For the helper below, leave
              "Loop" OFF on the AudioSource.
- RPG Maker:  Loop OGG files in audio/bgm/, cues in audio/se/.
- The Full versions are ideal for trailers, credits, and endings.


PLAY, REST, COME BACK
---------------------
Godot 4 (GDScript) - save as area_music.gd and add it as an Autoload
named AreaMusic. Call AreaMusic.play_area(stream) when an area starts.

    extends Node
    @export var repeats := 2
    @export var rest_seconds := 30.0
    const ON := -8.0
    const OFF := -60.0
    var player := AudioStreamPlayer.new()
    var cue := AudioStreamPlayer.new()
    var passes := 0
    var generation := 0

    func _ready() -> void:
        add_child(player)
        add_child(cue)
        player.finished.connect(_on_finished)

    func play_area(stream: AudioStream) -> void:
        if player.stream == stream and player.playing:
            return
        generation += 1
        passes = 0
        player.stream = stream
        player.volume_db = OFF
        player.play()
        create_tween().tween_property(player, "volume_db", ON, 3.0)

    func _on_finished() -> void:
        passes += 1
        if passes < repeats:
            player.play()
            return
        passes = 0
        var mine := generation
        await get_tree().create_timer(rest_seconds).timeout
        if mine != generation:
            return  # the player moved on during the rest
        player.volume_db = OFF
        player.play()
        create_tween().tween_property(player, "volume_db", ON, 6.0)

    func sting(stream: AudioStream) -> void:
        cue.stream = stream
        cue.play()

On death:

    AreaMusic.sting(doom)
    AreaMusic.play_area(no_way_out)

Unity (C#) - an AudioSource with Loop OFF, plus one for cues:

    using System.Collections;
    using UnityEngine;

    public class AreaMusic : MonoBehaviour
    {
        public AudioSource source, cue;
        public int repeats = 2;
        public float restSeconds = 30f, level = 0.45f;
        Coroutine run;

        public void PlayArea(AudioClip clip)
        {
            if (source.clip == clip && run != null) return;
            if (run != null) StopCoroutine(run);
            source.clip = clip;
            run = StartCoroutine(Run());
        }

        public void Sting(AudioClip clip) => cue.PlayOneShot(clip);

        IEnumerator Run()
        {
            while (true)
            {
                source.volume = 0f;
                source.Play();
                StartCoroutine(FadeIn(4f));
                yield return new WaitForSeconds(source.clip.length);
                for (int i = 1; i < repeats; i++)
                {
                    source.Play();
                    yield return new WaitForSeconds(source.clip.length);
                }
                yield return new WaitForSeconds(restSeconds);
            }
        }

        IEnumerator FadeIn(float seconds)
        {
            for (float t = 0f; t < seconds; t += Time.unscaledDeltaTime)
            {
                source.volume = Mathf.Lerp(0f, level, t / seconds);
                yield return null;
            }
            source.volume = level;
        }
    }

The fade-in also hides the one-second trace of the ending that the
loop crossfade leaves at the very start of each loop file.


IF YOU LIKE IT
--------------
There are more volumes, all built the same way, all royalty-free:

  https://wafusoundworks.itch.io

Where to go from here:
  - When the verdict turns into a real fight:
      Vol.30 Boss Battle - sealed door, first form, second form, the
      true enemy, and the empty hall afterwards.
  - The floors above Yomi:
      Vol.13 Dungeon - beneath the shrine, with a real safe room.
  - The spirits on the road that leads here:
      Vol.7 Yokai Fantasy.
  - If your game is horror rather than myth:
      the Dark Quintet bundle (five horror volumes).

And four more free complete volumes: a platformer pack, a bullet hell
pack, a liminal pack and an exploration pack.

If this pack helped your project, a quick rating on its itch.io page
helps other developers find it:

  https://wafusoundworks.itch.io/wafu-vol19-japanese-underworld-music-pack

If something is wrong or missing, tell me first and I will fix it.
And what scene do you still not have music for? The answers decide
which volume comes out next.


LICENSE
-------
Royalty-free for commercial and non-commercial projects.
No credit required. See LICENSE.txt for full terms.
The license is identical to our paid packs. Free does not mean limited.

Made with the assistance of generative AI (Suno, commercial plan),
curated, edited, loop-engineered, and level-matched by a human.

Contact / support: syarumariann222638@gmail.com
Feedback and requests are welcome.
