# Scanner

Raw notes follow - major clean up needed

# player.experience set/give/take  (level) x : https://meta.denizenscript.com/Docs/Search/experience
#   - <player.xp>,  .xp_to_next_level, xp_total, xp_level
# Durability
#   <itemTag.durability>, .max_durability
#   https://meta.denizenscript.com/Docs/Search/durability
# OK, so this is harder than it appeared:
# -  inventory adjust slot:hand durability:<player.item_in_hand.durability.add[10]>
#  - You CANNOT use
#   - adjust player.item_in_hand.durability:10  (to set to 10) it is NOT sticky. Apparently the
#   item from in_hand is a COPY not a reference.
#   - or a more complex example from the  script:  https://forum.denizenscript.com/resources/hammer-time-incl-resource-pack.104/updates#resource-update-181
#   hammer_durability_helper:
#       type: task
#       debug: false
#       definitions: item|durability
#       script:
#       - if <player.gamemode> == creative:
#           - stop
#       - if <[item].durability.add[<[durability]>]> >= <[item].max_durability>:
#           - inventory set slot:hand o:air
#           - playeffect effect:ITEM_CRACK at:<player.location.above[0.5].forward[0.4]> special_data:<[item].material.name> offset:0.2 quantity:15
#           - playsound <player.location> sound:ENTITY_ITEM_BREAK
#       - else:
#           - inventory adjust slot:hand durability:<[item].durability.add[<[durability]>]>
#
#   - See: https://guide.denizenscript.com/guides/troubleshooting/common-mistakes.html#so-how-do-i-adjust-a-specific-item
#
# For mining a general rule of thumb is branch mining uses 37.5% of the blocks in the 3D area.
#   - TODO: Adjust durability as if the area is being branch mined
#
# player.location.find_blocks[coal_ore].within[16]  (returns list of cordinates)
#   - Example FROM chat: /ex narrate 'results: <player.location.find_blocks[coal_ore].within[16]>'
# player.location.find_blocks[coal_ore].within[16].size (returns count)
# ?? How to create cubiod around player, exmaple find only matches on same Z
#  - https://github.com/Hydroxycobalamin/Denizen-Script-Collection/blob/main/external/Hammer%20Time/hammer.dsc
#  - https://github.com/mcmonkeyprojects/DenizenSampleScripts/blob/master/selector_tool.dsc
#  - it does appear Denizen uses radius and the only way to get it to use a cube is to loop through the blocks manually?
#   - Confirmed it is spherical via experiments using blocks at corner of square and then identify edges of sphere
#   - or do some fancy geometry of dimensions spheres
#   - or scan a larger area and ignore items outside that.
#   - all of that seems tedious and slow for this
#  - use basic radius (increase to conver entire cube of dimensions r) is a  huge impact on the lookup
#       - 16*16*16 = 4096 goes to 21*21*21 = 10,648 which is 2+x slower for no big benifit
#       - consider setting duarability to actual area or just charge more for have the luxury of a scanner
#       - sphere of r 16 = 3217  (4pi r^2) vs 16 cube at 4096
#  - hmmm a diamon pickaxe has a durability 1561 which is just enough for ONE 16x16x16 scan that seems excessive
#       - a stone pickaxes is only 131 and 8 radius = 192

# assume branch mining effeciency which is about 37.5% assuming player wants to find
# all blocks. And use 1 durability (breaking cobbelstone) as if branch minign eas being used
#   - durability: cost per adjusted block in the area
#   - area_type: How the block area is calculated for cost. The SCAN is always on a 3D sphere
#       - sphere: Total spherical area (3d) (pi * r^3 * 4/3) which is less than a cube of r*2 size
#       - cube: A cube of sides each r (scan is still spherical)
#       - circle: Only a circle around the player (2d) (pi * r^2) (ends up being a more reasonable cost)
#       - square: A square of sides each r (scan is still spherical) (ends up being higher than circle)
#       - fixed: cost is per range adjusted by 3D range scaling (so 8 to 16 is 2x*2x*2x = 8x more)
#   - Tips:
#       - for branch mining set the duability to be 0.375 on sphere or circle
#           - on a circle considering using : 0.75 since player needs to break 2 blocks verically to move
#       - for creatures the most likley reasonable use is outside so consider adjusting to higher visual range
#           - type: square
#           - a durabilty cost of 0.01
#           - for the above:
#               - each scan of 32 is 3,317 and a cost of 0.1 = 33 is A stone sword (132 duability) would get 6 scans
#
# Tip: Gold is SUCH low duability and a tad expensive so allow size to increase but duability not be affected
#   - A: Calculate cost BEFORE adjusting range
#   - B: the scaling factor used for range is inverted for duability
#       - scan range 8 goes to scan range 16
#       - Durability area calcualtion uses 4 radius instead o 8
#       - Example: scan range 8 => 16 using circle = 804 blocks * 0.375 (banch) = 301.5 (302) (which is 5 attempts with a diamond tool)
#       - for duability:  range 8 => 4 using circle = 50 * 0.375 (branch) = 19 (which is 1 use)
#   - C: or adjust gold to be same durability of Diamond via adjusting durability
#       - a radius of 16 using circle is 804 blocks
#       - gold is 32 durability and diamond is 1561
#       - so factor is 48.78 so duability becomes : .02 and then with branch mining = .0077
#       - so the same  16 radius (un adjusted) = 804 blocks * .0077 = 6.19 whcih rounds to 6 so gold at 32/6 = 6 scans, a bit better than diamond
#       and seems reasonable given user will likley need to switch items a lot to reach the target. Given that maybe use netherite as base?
#
#  - on averge there are 20 deposits of iron per chunk (and about 4 per deposit). So it would take 20 scans to find
#       - remove 6 blocks (r) per level to see MOST iron deposits = 6 * 8 = 48
#       - let's assume 30 levels contains most of the iron (it's more but this seems reasonable)
#       - since we mine 2 layers and the 1 below and 1 anbove we can see that means 48 blocks gives us 4 layers
#           - some ores will be hidden, especially single ones, in the corners but ignroe that
#       - 48 * (30/4) = how much mining to get most of the iron = 300
#       - based on https://minecraft.fandom.com/wiki/Iron_Ore the max number of deposits that could be in a chunk
#        seems to around 110 across a WIDE range.
#       - Now scanning only shows NEAREST ore,
#
# TIP: Since find is in spherical areas it is nice to know a general  rule to search without voids. There are optimal
# algorithims such as ClosePacking, Face-Centered Cubic and others. But these are a bit complex for a player to comfortable
# runa round a mine using. So a general rule of thunmb you can use is to move from the center of the last scan by
# (R * sqrt(3)) = so for an 8 radious move 13 from last scan. This was identified by ChatGPT and I found some vague
# references online. I validated the approach (in general) through grid paper and circles. Spheres where not used
# as the cirlces work well for the mining algoriothm a player could utilize.
#       - sqrt(3) == 1.73 -- this seems a bit more accurate than the 2/3 but not sure they are close
#
# TIP: If we decide to use circles instead an easier aglorhtm is (3/2 * R) which is (1.5 ^r). THis is 
# a bit more overlap so is safer
#   - 2/3 * 32 = 46
#   - sqrt(3) * 32 = 55
#
# Default duability without magic (sword and pickaxe are identical)
#   TIP: Gold is WAY better than all others for scans. It has double the range and can scan
#   that range the same number of times netherite can scan a range of 8
#




## Appendix

# ChatGPT help for overlapping coverage: spheres

Prompt: This was a conversation to adjust ChatGpt to move from complex agorithms to more general, if less effecient ones.

Answer: (modified for readability) For a quick and practical solution that guarantees complete coverage while covering an infinitely large area with spheres of radius 8, you can arrange the spheres in a cubic grid pattern where each sphere's center is more closely spaced than just their diameters would suggest.

A simple rule could be to place each sphere such that its center is a distance of 8 * sqt(3) ≈ 13.86 units away from the centers of its nearest neighbors in the grid. This distance is derived from the diagonal of a cube that would just encase the sphere.

This approach, while not optimally efficient in terms of the number of spheres used, ensures complete coverage without voids and is easier to calculate and implement than a close-packing arrangement.

Test: Then this was tested and found reasonable.

# ChatGPT help for overlapping coverage: cirlces

Prompt: Ok, let's get specific. I am mining an area in Minecraft. I have a mod installed that detects ores within a radius of 8 (a sphere). To be most effeceint I would like to know how far I should walk forward before scaning agian. I prefer to guarntee I get ALL ares covered and do not mind overlapping regions. It needs to be simple so I can perform it in game as a player. For esample I could just move 2 forward and scan and that would workd but would be very ineffeceint. I could move 16 forward and guarentee no overlaps but I would miss out on a LOT of potentiial ores. Do you have any thoughts on how many blocks would be good to more forward to be effeceint and guarnetee finding all ores.

Prompt: Can you provide an algorithm based on radius?

Answer: (adjusted to be readble as text) Certainly! You can use a simple formula based on the radius of your detection sphere to determine how far to move forward between each scan. This formula ensures coverage without significant overlaps, and can be adjusted if the radius changes.

Formula:

    Move forward by approximately (3/2 × radius)

Explanation:

    If your detection radius is R, moving forward by 3/2 * RR allows for a slight overlap of the detection areas, ensuring complete coverage without excessive redundancy.

Example:

    If your radius is 8 blocks, move forward by 3/2 × 8 = 12 blocks
    If the radius changes to 10 blocks, move forward by 3/22 10 = 15 blocks.

This formula provides a balance between coverage and efficiency, adaptable to different detection radii. It's straightforward to apply in-game, making it a practical choice for Minecraft mining activities.


Test: Then this was tested and found reasonable.
