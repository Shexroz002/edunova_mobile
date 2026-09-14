# Chat design canvas

Published canvas: https://claude.ai/code/artifact/67c45418-b656-4d55-9546-6b076b66f20d

Seven screens in dark and light: chat list, chat room, attachments, message actions,
forward/new-chat picker, chat info, states.

`*.dc.html` are the artboards; `canvas.json` is the layout. Both themes are generated from one
source, so they never drift: edit `gen_*.py` and run `python3 build.py`. Colours come from
`lib/core/theme/app_colors.dart` — never hardcode new ones here.
