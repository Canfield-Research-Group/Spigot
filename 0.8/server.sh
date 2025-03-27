#!/bin/bash

# FILE: server.sh
#   - Used by tmux or other systems to JUST start the server

# With 8 GB in the machine, 6 GB had MC run out of RAM, so try 4 and see if server handles that
memoryGB=4
#memoryGB=8

# See also https://paper.readthedocs.io/en/latest/server/aikar-flags.html
# Download latest - only takes a second or so
export getLatest=1.21.4
if [[ -n "$getLatest" ]]; then
  curl -o purpurmc.jar https://api.purpurmc.org/v2/purpur/${getLatest}/latest/download
fi


# Set RAM to max minus 1 GB (the OS does not need that much bue play it safe for maintenance)
# - NOTE: Even through the server dhows free mem of 7.6 GB a 7 GB limit seems to fail due to RAM
#   on some starts. I( blam Java really weird memory settings. Potentially 6.5 would work.
# NOTE: the "add-modules=jdk.incubator.vector" is a Puuferfish extenion inheroted by PurPur and
# is supposed to speed up some matrix operations whihc beneifit Minecraft. It was encouraged by
# during mincraft startup INFO messager (1.19.2). Note it uesses DOUBLE '--' syntax
java \
-Xms${memoryGB}G -Xmx${memoryGB}G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
-XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \
-XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
-XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \
-XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs \
--add-modules=jdk.incubator.vector \
-Daikars.new.flags=true \
-jar purpurmc.jar nogui
# APPEND this to above when UPGRADING Minecraft Versions: --forceUpgrade (optional for Paper/PurPur but
# should speed up rendering to avoid on-demand chunk updates)

# Trigger a backup - will create a backup one a day at MOST and update that
# backup if done multiple times a day
# DISABLED until I can get block backup implemented
#../backup.sh
