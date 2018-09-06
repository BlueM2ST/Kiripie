# The 'scenario' file:

This file should contain all the custom non-gd scripts. You can see examples of the syntax in the sample_ files.

# *.kp files

These files will contain all the game tags and dialogue (unless you set it up for localization, then the dialogue will be in a *.lang file). 

There are two important jump tags in every game: *config, *menu, and *splashscreen. The config.kp file (with *config) is required to run any game made with 
this tool and should probably not be edited. *splashscreen is where the game will begin to be displayed. From there, all jump tags can be 
whatever you need them to be. *menu is where all menus will be defined.

# scripts.kps

This is where all the scripts for buttons will go. They are written in GDScript, but combined into one file for easier assigning of 
scripts to the generated buttons.

# *.lang

This will contain localized dialogue. To use this, the original dialogue will have to also be in one of these files (which can be easily done 
using a customized script).

# grammar.kpcf

This is used for debugging. In this version (0.9.0), the debugger is disabled, so this script doesn't do anything in the game. 
However, you can look at it for the syntax of every tag that can be used in the game. The subtags are in RegEx.