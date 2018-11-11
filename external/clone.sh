#!/bin/sh

git submodule add https://github.com/DrProfesor/odin-assimp.git
git submodule add https://github.com/vassvik/odin-gl.git
git submodule add https://github.com/vassvik/odin-gl_font.git
git submodule add https://github.com/vassvik/odin-glfw.git
git submodule add https://github.com/vassvik/odin-stb.git

git submodule add https://github.com/ThisDrunkDane/odin-imgui.git
cd odin-imgui
git checkout c55f6f11ee7c1226eca22d5affc743bebe857616
# git submodule update --init --recursive
https://github.com/shwaDev/odin-glfw