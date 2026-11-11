# Drift shell surfaces (template). drift-recolor fills the colour tokens from
# the palette Aether extracts from the current wallpaper.

[bar]
background = "{{darker_background}}"
background-alpha = 0.62
text = "{{foreground}}"
active = "{{orange}}"
scale-with-font = true
size-horizontal = 28
size-vertical = 30
icon-size = 11
icon-font = 12

[hyprland]
active-border = "{{accent}}"
active-border-foreground = "{{foreground}}"

[controls]
normal-color = "{{foreground}}"
normal-fill-alpha = 0.03
normal-border-width = 0
normal-border-alpha = 0.0

hover-cursor-color = "{{bright_foreground}}"
hover-cursor-fill-alpha = 0.08
hover-cursor-border-width = 0
hover-cursor-border-alpha = 0.0

focus-color = "{{accent}}"
focus-fill-alpha = 0.10
focus-border-width = 1
focus-border-alpha = 0.45

selected-color = "{{accent}}"
selected-fill-alpha = 0.16
selected-border-width = 0
selected-border-alpha = 0.0

pressed-fill-alpha = 0.20
selection-fill-alpha = 0.30

[spacing]
scale = 1.05
scale-with-font = true
panel-padding = 20

[font]
base-size = 12

[popups]
background = "{{background}}"
background-alpha = 0.92
text = "{{foreground}}"
border = "{{foreground}}"
border-alpha = 0.12
border-width = 1

[tooltip]
background = "{{background}}"
background-alpha = 0.94
text = "{{foreground}}"
border = "{{foreground}}"
border-alpha = 0.10
border-width = 1

[notifications]
background = "{{background}}"
background-alpha = 0.92
text = "{{foreground}}"
border = "{{foreground}}"
border-alpha = 0.12
border-width = 1
countdown = "{{accent}}"

[launcher]
background = "{{background}}"
background-alpha = 0.90
text = "{{foreground}}"
border = "{{foreground}}"
border-alpha = 0.12
border-width = 1
scrim = "{{darker_background}}"
scrim-alpha = 0.35
selected-background = "{{accent}}"
selected-background-alpha = 0.14
selected-text = "{{bright_foreground}}"
selected-border = "{{accent}}"
selected-border-alpha = 0.0

[menu]
background = "{{background}}"
background-alpha = 0.92
text = "{{foreground}}"
border = "{{foreground}}"
border-alpha = 0.12
border-width = 1
scrim = "{{darker_background}}"
scrim-alpha = 0.35
selected-background = "{{accent}}"
selected-background-alpha = 0.14
selected-text = "{{bright_foreground}}"
selected-border = "{{accent}}"
selected-border-alpha = 0.0

[polkit]
background = "{{background}}"
background-alpha = 0.95
text = "{{foreground}}"
text-error = "{{red}}"
border = "{{foreground}}"
border-error = "{{red}}"
border-alpha = 0.2
border-width = 1
scrim = "{{darker_background}}"
scrim-alpha = 0.5
accent = "{{accent}}"

[lock]
background = "{{darker_background}}"
background-alpha = 0.55
text = "{{bright_foreground}}"
placeholder = "{{dark_foreground}}"
text-error = "{{red}}"
border = "{{foreground}}"
border-active = "{{accent}}"
border-error = "{{red}}"
border-alpha = 0.35
border-width = 1
selection = "{{accent}}"
selection-alpha = 0.40

[image-picker]
text = "{{foreground}}"
selected-border = "{{accent}}"
selected-border-alpha = 1.0
unselected-border = "{{foreground}}"
unselected-border-alpha = 0.22
