# CustomHUD Extended

Original addon can be found at [Syllendel/CustomHUD](https://github.com/Syllendel/CustomHUD)

Tested on Ashita 3 @Wings server.

## Extended features


### Target HP gauge

The gauge should display when you target other players or mobs with hp/Name, hpp% and distance can be turned off in `themes/default/theme_settings.json`

Can be toggled on/off with `/hud tg` (tg for Target Gauge)

![Imgur](https://imgur.com/RhFMNAD.png)

### Sub-target cursor

Blue cursor for `<stpt>`, orange cursor for current target and `<stpc>`

![Imgur](https://i.imgur.com/syQijWY.png)

![Imgur](https://i.imgur.com/5aZniIz.png)


### Party hpp%

Enabled automatically when switching main job to DRG. 

Can be toggled manually with `/hud hpp`

![imgur](https://i.imgur.com/mRgbyFE.png)

## Cut features

* The addon in its current state only support default theme. Other themes had not been updated to be compatible and had been removed from this repository

## Commands
/hud lock: Allow you to move the hud with left click, doing this command again lock it back so it won't intercept mouse.\
/hud hide: Show/Hide the hud\
/hud debug: Show the id of the buffs/debuffs\
/hud theme nameOfTheTheme: Change the theme

## Recurrent problem
If the hud disappear randomly, it means memory location used to detect if the chat is expanded is not correct (due to an update or modified client)\
To avoid this you have to adjust the following settings:
* **hide_when_expand_chat_default_behavior** inside settings.json, it's the default hiding behavior if not specified in a theme
* **hide_when_expand_chat** inside theme_settings.json (in each theme) will prevail over the default option if set
