
# # Fair XP Anvil
#
# Changes the XP Level cost for Anvil use to an XP Points based on those levels.
# This resolves a long standing issue with anvils that
#
# Limitations:
#   If the player accumulated XP between placing items in anvil and taking result then they
#   will loose that XP. This is considered rare and in any case, the loss is typical far less than what was gained with FAIR XP.
#   The work around for that is a rather complex 'on player' check, followed by waiting for a clock tick then applying a COST adjustment.
#   That solutions is VERY fragile and has added complexity over far simpler and good enough solution:
#
#   Enchanting table is NOT supported; it is a more complex object than the anvil
#
#  TODO: Consdier adding support to enchanting table
#


fxp_commands:
  type: command
  debug: false
  name: xptotal
  description: Shows your detailed experience info
  usage: /xptotal
  permission: xptotal.use
  script:
    - narrate "TEST"
    - define player_level <player.xp_level>
    - narrate "Level: <[player_level]>"
    - narrate "Lifetime XP: <player.xp_total>"
    - narrate "XP to next level: <player.xp_to_next_level>"
    - narrate "Progress to next level: <player.xp>%"
    - define calculated <proc[fxp_points_for_player].context[<player>]>
    - narrate "Calculated points: <[calculated]>"
    - define cost_5_levels <proc[fxp_points_for_level].context[5]>
    - narrate "Points for level 5 spell (from level 0): <[cost_5_levels]>"
    - define player_cost_5_levels <proc[fxp_points_for_level].context[<[player_level].sub[5]>]>
    - narrate "Player actual points if spending 5 levels: <[calculated].sub[<[player_cost_5_levels]>]>"
    - narrate "NOT FAIR: 5 levels should be the same cost no matter where the player is, otherwise it encourages gaming the system"


# === Events to handle anvil using points instead of levels
fxp_point_anvil:
  type: world
  debug: false

  events:
    # Fires when anvil result is calculated, lets us see cost
    # this can fire 3-4 times but the cost to track and debounce is almost as high as just recalcuting so recalc (easier)
    on player prepares anvil craft item:
      #- if !<player.is_op>:
      #  - stop

      - define player <player>
      - define cost_levels <context.repair_cost||0>
      - define player_level <[player].xp_level>

        # When cost is 0 or less (-1 was seen) ingrediants were probably removed or anvil canceled
        # When levels are more than player has just let GUI tell them. Our cost calculations are ALWAYS less than GAME (XP Fair)
        #    In both case CLEAR any excisting Anvil flag
      - define prior_cost <player.flag[fxp.anvil_point_cost]||0>
      - if <[cost_levels]> <= 0 or <[cost_levels].is_more_than[<[player_level]>]>:
          - debug loag "<gold>FLAG CLEARED"
          - if <[prior_cost]> 0:
              - flag <[player]> fxp.anvil_desired_xp:!
          - stop

      - define player_xp <proc[fxp_points_for_player].context[<[player]>]>
      - define cost_xp <proc[fxp_points_for_level].context[<[cost_levels]>]>
      # checking foe xp is not need here since we are using LESS XP than the game so let the GUI handle the display check

      # A duration is often used (duration 5s) to make sure the flag is cleared. In our case we  localize
      # flags so I don't think this will be a problem and so no duration is used
      #   Set a long duration so flag eventually garbage collects. But it should that on any anvil change die to cost check above
      - define desired_xp <[player_xp].sub[<[cost_xp]>]>
      # Very simple de-bouncer that does not require more flags
      - if <[prior_cost]> != <[cost_xp]>:
        - flag <[player]> fxp.anvil_desired_xp:<[desired_xp]> duration:5m
        - narrate "<green>Post Fair XP adjustment: <proc[fxp_points_for_player].context[<[player]>]>"



    # Fires when player clicks the result slot to complete the anvil merge
    #   Inventory objct: <context.inventory||null>
    #   Inventory Type: <context.inventory.inventory_type||none>   -- (UPPERCASED) ANVIL / ...
    #   Slot type: <context.slot_type||null> -- (UPPERCASED) CRAFTING / RESULT / ...
    #   Action : <context.action||null> -- (UPPERCASED) PLACE / PICKUP_ALL / ...
    #
    # On sucess will set player xp to the calculated level at anvil setup
    #   Limitation: If the player accumulated XP between placing items in anvil and taking result then they
    #   will loose that XP. This is considered rare and in any case, the loss is typical far less than what was gained with FAIR XP.
    #   The work around is a rather complex 'on player' check, followed by waiting for a clock tick then applying a COST adjustment.
    #   That is VERY fragile and has added complexity over farr simpler and good enough solution:
    #         See: https://meta.denizenscript.com/Docs/Search/clicks%20in%20inventory
    after player clicks in inventory:
      #- if !<player.is_op>:
      #  - stop

      - define player <player>


      #- debug log "<red>Clicks in inventory: inventory -- <context.inventory||NA>"
      #- debug log "<red>Clicks in inventory: inventory_type -- <context.inventory.inventory_type||NA>"
      #- debug log "<red>Clicks in inventory: slot_type -- <context.slot_type||NA>"
      #- debug log "<red>Clicks in inventory: action --  <context.action||NA>"

      - if <context.inventory.inventory_type||null> != ANVIL:
        - stop
      - if <context.slot_type||null> != RESULT:
        - stop

      # Get cost calculated when anvil was prepared, this flag may not be set if the anvil repair cost was not set or 0
      - define player_desired_xp <[player].flag[fxp.anvil_desired_xp]||0>
      - if <[player_desired_xp]>:
          # Set player XP to exactly what it costs to perform the action. This allows any expereince
          # that might be assigned to the player during the upcomming WAIT to still be abosrbed instead of lost
          # While gaining XP from some event while processing the ANVIL action would be rare it is possible
          - experience set <[player_desired_xp]> player:<[player]>

          # Clear cost flag
          - flag <[player]> fxp.anvil_desired_xp:!




# === Set XP for player to desired amount, after waiting a momement
fxp__restore_xp_after_tick:
  type: task
  definitions: player|desired_xp
  debug: false
  script:
      # Be safe and normalize object
    - define player <[player].as[player]>

    # Allow any pending minecraft actiont o continue
    # === DOES THIS WORK?
    - wait 1t

    # - DEBUG
    - define new_xp <proc[fxp__points_for_player].context[<[player]>]>
    - debug log "<gold>NEW XP (should be zero): <[new_xp]>"

    # We expect the player to be at LEVEL 0 if our calculations are perfect UNLESS an external event in the 1t
    # granted out character some points (xp farm of whatver) then we ant to retain that. I expect that will
    # be REALLY rare.
    - narrate "<gold>Adjust to desired: <[desired_xp]>"
    - experience give <[desired_xp]> player:<[player]>
    - define new_xp <proc[fxp__points_for_player].context[<[player]>]>
    - debug log "<green>NEW XP: <[new_xp]>"


# === Get current points for a player (round down)
fxp_points_for_player:
  type: procedure
  debug: false
  definitions: player
  script:
    - define level <[player].xp_level>
    - define progress <[player].xp>
    - define to_next <[player].xp_to_next_level>
    - define base_xp <proc[fxp_points_for_level].context[<[level]>]>

    # progress to next level is in percentage, we need it in decimal
    - define extra_xp <[progress].div[100].mul[<[to_next]>]>
    - define total_xp <[base_xp].add[<[extra_xp]>]>
    - determine <[total_xp].round_down>

# === Get points for a specific level. This forces whole number levels only (round down)
# Best used to identify how many points a cost of 5 levels means without regard to current players level.
fxp_points_for_level:
  type: procedure
  debug: false
  definitions: level
  script:
    - debug log "<red>Level: <[level]>"
    - define level <[level].round_down>
    - if <[level].is_less_than_or_equal_to[16]>:
      - define base_xp <[level].mul[<[level]>].add[<[level].mul[6]>]>
    - else :
      - if <[level].is_less_than_or_equal_to[31]>:
          - define base_xp <[level].mul[2.5].mul[<[level]>].sub[<[level].mul[40.5]>].add[360]>
      - else:
        - define base_xp <[level].mul[4.5].mul[<[level]>].sub[<[level].mul[162.5]>].add[2220]>

    # progress to next level is in percentage, we need it in decimal
    - determine <[base_xp].round>

