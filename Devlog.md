GameLab Devlog
09/02
Game ideas? Learn japanese (kanjis), maths, physics? Math progression? Plateformer puzzle game?
We are learning Japanese, so let's try to make a game to help us learn kanjis.

16/02
Game to learn japanese/japanese kanjis
What is fun when learning kanjis ? 
How do we learn kanjis ? 
→ Learn the meaning of a kanji and how to write it
→ Then learn its pronunciation in different context

02/03
Ideas:
Sandbox (combining basic kanjis to create new ones)
Kanji ninja (write the kanji quickly, fruit ninja style)
RPG (fight monsters and explore a dungeon with spells based on radicals, skill tree that starts from the radical and unlocks new spells)
Kanji boss battle (fight a monster by writing the requested kanjis, e.g. write "person" to deal damage to the boss based on writing speed and accuracy) 


09/03
Beat the Kanji
Unlock the next level based on experience gained
In each level:
3 new kanjis to learn (to be confirmed) + previously learned kanjis one card per kanji with the kanji, its meaning and its pronunciation depending on context
a boss that takes a new form every 10-20 seconds (random timer)
an image of the kanji's meaning the kanji itself its Japanese pronunciation (kun'yomi) or Chinese (on'yomi), in hiragana or romaji
If time runs out, the kanji attacks with a word (-> find the right pronunciation)
You collect coins and experience 
each time the monster changes form, the player chooses between the kanji, one of its pronunciations, the image of its meaning… among the other kanjis in the level to deal damage
The player can consult the card during the level if they have enough resources
Platform: Python/Unity?/Construct?



16/03
Platform: Godot, learning how to use it
Other game mechanics:
buying bonuses, equipment with collected coins
consulting the kanji card (for the current question): costs x coins, doesn't pause the game timer during consultation (hard mode?)
final battle: use the coins earned to buy equipment and/or bonuses
The monster to defeat is a sentence made up of the kanjis to learn. It sends its elements at us to fight them (the info cards appear). When one is defeated, it goes back onto the monster-sentence. At the end, we have to defeat the whole sentence: final battle.
Implement a drawing phase?
From time to time (+ at the end of each intermediate phase), a stroke order exercise appears: at first, instructions on stroke order are shown, then they disappear.
Finishing move: draw each kanji perfectly: the samurai's ultimate technique.
Implement a sandbox section? With the different cards?
Godot → mobile game for kanji drawing?

Adobe Firefly for the images?


30/03
Timer to answer each question: if you don't answer fast enough, the kanji changes form (e.g.: stroke order -> image or image -> on'yomi…) 


13/04
Presentation of the prototype on Godot
Show kanji cards at the start of each phase 
TODO: 
- add more kanjis (fill out the database)
- new items
- animations
- clean UI game
- mechanics:
	- do something with the kanjis you collect: a sentence?
	- ability to combine kanjis?
	- timer hints the monster attacks: possibility to parry randomly, with timed kanji drawings: 10sec; if you fail, the monster hits harder
	- intermediate phase: answer questions about the kanji (reading, meanings)
	- zones (aesthetics): plains, snowy mountains, erupting volcano, tropical island, weather
=> you can unlock spells with the kanjis you collect along the way: e.g.: you get 火, 曜 and 日 => creates the spell "火曜日" (Tuesday) which is a fire spell.
You can use other versions (水, … (other days of the week)?). In a level, the spell is only available if you've "collected" the level's kanjis (i.e. if you answered the questions tied to those kanjis correctly)
Spells are grouped into categories based on the kanjis that make up their name (e.g.: fire category with all spells whose name contains the kanji "火")


11/05
Added some UI graphics and better fonts, translated parts of the game that were still in french
Created a “Help” and “Credits” section in the main menu to give info on how to play the game and who worked on it
Wrote a readme to give guidance to people that will work on the game later
Todo: export the game for windows, mac and android.
