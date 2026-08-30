# Playthrough 1 — 24/25 Aug

One session, front to back, on a device. The wording below is the report's own;
what has been added is the box and, where a row was not a straight fix, a line
saying what was done instead.

- [x] 1. name of app should be merge empire football manager, with spaces between things
- [x] 2. on home screen, the backdrop only goes up about 50px then is fully cut off, we should use a shadow backdrop if there is one in the kenney pack in tier1/2 or totally get rid,
      — kept the trees: `parkTreeline.png` is the same plate with its sky knocked
      out, so the scene's own sky shows through and there is no edge left.
- [x] 3. the play button when on players has too much text, it should just say 'Need 3 players' and the font needs to look better than it does now.
      — `play.need_players_short` is the shipped key for exactly this slot and had
      no caller.
- [x] 4. customise button brings up a popup which comes up a bit laggy
      — a chip a frame, started at once rather than after the slide.
- [x] 5. clicking on a locked item in them customise for a manager should bring up a toast saying how to unlock it i..e unlock by building fan zone 4 for exmaple
- [x] 6. skin shoul dsay the skin colour and not an rgb colour
      — numbered, `customise.item.skin.tone`, which is the spec's own answer: the
      swatch carries the information and invented names for eight shades of skin
      are worse than "Tone 3" in any language.
- [x] 7. hats should hide hair, hair shouldnt be popping out of the top of hats
      — the brow line was not enough on its own; the hair is clipped to the skull
      under a solid crown, and a bun goes UNDER the wool rather than behind it.
- [x] 8. where are the celebrations we can unlock for the manager? they are all in ../merge-empire-fc
      — nine gestures, named in ten catalogues, with no tab to reach them. The
      emote axis equips nothing and plays on the preview instead.
- [x] 9. most of the manager rig customisations can be clicked on to view an advert, but none of them have an advert icon on to show this?
- [x] 10. i dont like how in global leaderboard we have 3 rows of things, make it one row with select drop downs
- [x] 11. in light mdoe, the trophies text is yellow with a border, cant read it properly in ligh tmode
- [x] 12. the energy popup that appears at the bottom, the energy refill button should have 5 and then a gem icon, and it should be in the same place as the button in the advert - at the bottom, also you have 'already ready' in the energy one... no its not.
- [x] 13. the emboss of numbers on the players tab looks bad, can hardly see the numbers, make them more visible.
- [x] 14. when a bid comes in, the minimise ubtton in light mode has grey text on green, the othres have white, firstly the accept button should be the only green one and the coin should be in yellow with a coin icon next to it, the dceline should be in red, and minimise well we should just put a - button in a box top right so people can click on that to minimise, or can just click in background
- [x] 15. on club page
      — **the line stops there.** Nothing to act on; it needs saying again.
      CLOSED as unactionable rather than left open: a row with no content cannot
      be finished, and carrying it forever makes the queue's count a lie. If it
      is remembered, it comes back as a new row.
- [x] 16. in the shop on special offers the top right badges go over the button to buy, we have quite a bit of room here, use it - also the grey background on them look sboring, look at ../merge-empire-fc - that had nice colours on them.
- [x] 17. the coin pack buttons are greyed out where as the gem ones are green and clickable
- [x] 18. on boosts, the magic sponge has no injured players, that text shoudl be in red so its obvious.
- [x] 18b. energy refill in shop says +{n} energy... needs to have the real number
      — it is the TANK, so an Energy Director owner gets fifteen.
- [x] 19. quick fire matches and free lukcy boot, both say 'Already ready'
- [x] 20. manager customisations in the shop - when you click on one to buy it shows a tiny image of it, make those images bigger and put them in a box similar to how they look when you click on the customise button. Plus the gem amount on this page is in yellow, the gem and the 5 should be ON the buy now page.
- [x] 21. The cancel buttons are grey with a weird white top, i think its meant to look 3d, but all the other buttons have the 3d from the bottom not from the top.
      — the coach card's buttons were not getting the app's moulding at all:
      `styleFrom`'s `backgroundColor` colours the Material UNDER the face the
      theme's own builder then paints over.
- [x] 22. privacy options not doing anything, but thats on the simulator
      — the report's own diagnosis, and it is right: the consent SDK has no UI on
      a simulator. Nothing changed. CLOSED: there is no defect here to fix, and
      the device pass that would show the form is already its own row in
      `REMAINING.md`.
- [x] 23. when starting a game, the team name should be randomised, its up to the user to choose one.
- [x] 24. teh cancel buttons shoudl always be in red.
- [x] 25. the team names button shows no teams as if there are no teams in the pyramid even though there are.
      — the pyramid is built lazily and the editor was reading it raw.
- [x] 26. there is no message on difficulty to say you need to prestige to unlcok it - needs to be clear its locked until prestige
- [x] 27. the auto sold animation is a bit pants, it was better in ../mege-empire-fc altho i do like the coins going up to the coin section
      — the card comes apart into twelve clipped pieces of its own face now
      (`burstAway`), which is where the JS spends its effort; the coins stay.
- [x] 28. on tutorial, the skip tutorial should be just text underneath the lets go button, doesnt need its own button, the lets go can be full
- [x] 29. when i lcick on see my squad in tutorial, the players are meant to animate in, and each one is meant to take about 0.5 seconds so you see them flow in to th eteam
      — `loan-card-enter` at the JS's own 500ms stagger, and the script now waits
      for the last one to land before it says anything else.
- [x] 30. the 2d pitch is completely cut off, it shows the middle part and thats it
- [x] 31. keep hearing bad sounds and posts and all sorts going on, but nothing on the 2d pitch??!? whats going on,
      — same fault as 30: the band held 16% of screen height against the spec's
      226 points, so a chance was a few four-point dots twitching in a letterbox.
- [x] 32. after winning, the tutorial shoudl let them go to the end game first, show the well done you won. then it should wait for the player to go back to the home screen, THEN it should show 'now build your team' popup. we get stuck on the game screen in the tutoroail right now.

## Still open from this pass

- Row 15 needs re-reporting — the sentence is one clause long.
- The loan players' DEPARTURE is still a cut. `loan_depart` in the JS flies them
  off before its card opens (`loan-card-exit`, 40ms apart); the port applies the
  save and then draws. Recorded in `docs/REMAINING.md`.
