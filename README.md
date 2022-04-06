# CustomHUD Extended

Original addon can be found at its creator [Syllendel/CustomHUD](https://github.com/Syllendel/CustomHUD)

## Extended features


### Target HP gauge

This gauge should show up when you select other players or monsters. Name, hpp% and distance can be turned off in `themes/default/theme_settings.json`

The gauge can be toggled on/off with command `/hud tg` (tg for Target Gauge)

![Imgur](https://imgur.com/RhFMNAD.png)

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
