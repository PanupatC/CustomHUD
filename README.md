# CustomHUD Extended

Original addon can be found at [Syllendel/CustomHUD](https://github.com/Syllendel/CustomHUD)

Tested on Ashita 3 @Wings server.

## Extended features

### Target HP gauge

`/hud tg` to toggle manually (tg for Target Gauge). Name, hpp% and distance can be turned off and adjusted positions in `themes/default/theme_settings.json`

![Imgur](https://imgur.com/RhFMNAD.png)

### Sub-target cursor

Blue cursor for `<stpt>`, orange cursor for current target and `<stpc>`

![Imgur](https://i.imgur.com/syQijWY.png)
![Imgur](https://i.imgur.com/5aZniIz.png)

### Party hpp%

`/hud hpp` to toggle manually. Will be enabled automatically if job set to DRG/support with healing breathe

![imgur](https://i.imgur.com/mRgbyFE.png)


## Cut features

* No longer support additional theme. Only default theme was updated and compatible.

## Commands
`/hud lock` : enable/disable position change with mouse drag\
`/hud hide` : Show/Hide the hud\
`/hud tg` : show/hide target gauge\
`/hud hpp` : show/hide HP%

## TODO

* Lockon indication
* settings to have hp% in front of hp number

## Recurrent problem
If the hud disappear randomly, it means memory location used to detect if the chat is expanded is not correct (due to an update or modified client)\
To avoid this you have to adjust the following settings:
* **hide_when_expand_chat_default_behavior** inside settings.json, it's the default hiding behavior if not specified in a theme
* **hide_when_expand_chat** inside theme_settings.json (in each theme) will prevail over the default option if set
